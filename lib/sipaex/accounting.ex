defmodule Sipaex.Accounting do
  @moduledoc """
  Accounting calendars and period lifecycle.

  This context owns the cross-module rules that decide whether an effective
  financial date belongs to an open, closing, closed, or locked period.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sipaex.Accounting.FiscalYear
  alias Sipaex.Accounting.JournalEntry
  alias Sipaex.Accounting.JournalLine
  alias Sipaex.Accounting.Period
  alias Sipaex.Accounting.PeriodEvent
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  def list_fiscal_years(%Organization{} = organization) do
    FiscalYear
    |> where([fiscal_year], fiscal_year.organization_id == ^organization.id)
    |> order_by([fiscal_year], asc: fiscal_year.starts_on)
    |> Repo.all()
  end

  def list_periods(%Organization{} = organization) do
    Period
    |> where([period], period.organization_id == ^organization.id)
    |> order_by([period], asc: period.starts_on)
    |> Repo.all()
  end

  def create_fiscal_year(%Organization{} = organization, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("organization_id", organization.id)
      |> Map.put_new("status", "open")

    %FiscalYear{}
    |> FiscalYear.changeset(attrs)
    |> Repo.insert()
  end

  def create_period(%Organization{} = organization, attrs, opts \\ []) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("organization_id", organization.id)
      |> Map.put_new("status", "open")

    Multi.new()
    |> Multi.insert(:period, Period.changeset(%Period{}, attrs))
    |> Multi.run(:event, fn repo, %{period: period} ->
      period_event_changeset(period, "opened", nil, period.status, opts)
      |> repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{period: period}} -> {:ok, period}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  def period_for_date(%Organization{} = organization, %Date{} = date) do
    Period
    |> where([period], period.organization_id == ^organization.id)
    |> where([period], period.starts_on <= ^date and period.ends_on >= ^date)
    |> Repo.one()
  end

  def period_open_for_date?(%Organization{} = organization, %Date{} = date) do
    case period_for_date(organization, date) do
      %Period{status: status} when status in ["open", "closing"] -> true
      _period -> false
    end
  end

  def ensure_writable_period(%Organization{} = organization, %Date{} = date) do
    case period_for_date(organization, date) do
      nil -> :ok
      %Period{status: status} when status in ["open", "closing"] -> :ok
      %Period{} -> {:error, :accounting_period_closed}
    end
  end

  def change_period_status(%Organization{} = organization, period_id, status, opts \\ [])
      when status in ["open", "closing", "closed", "locked"] do
    Period
    |> where([period], period.id == ^period_id)
    |> where([period], period.organization_id == ^organization.id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :period_not_found}

      %Period{} = period ->
        attrs =
          status_change_attrs(status, opts)
          |> Map.put("status", status)

        Multi.new()
        |> Multi.update(:period, Period.changeset(period, attrs))
        |> Multi.insert(
          :event,
          period_event_changeset(
            period,
            event_type_for_status(status),
            period.status,
            status,
            opts
          )
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{period: period}} -> {:ok, period}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  def close_period(%Organization{} = organization, period_id, opts \\ []) do
    change_period_status(organization, period_id, "closed", opts)
  end

  def lock_period(%Organization{} = organization, period_id, opts \\ []) do
    change_period_status(organization, period_id, "locked", opts)
  end

  def reopen_period(%Organization{} = organization, period_id, opts \\ []) do
    change_period_status(organization, period_id, "open", opts)
  end

  def list_journal_entries(%Organization{} = organization, opts \\ []) do
    JournalEntry
    |> where([entry], entry.organization_id == ^organization.id)
    |> maybe_filter_entry_dates(opts)
    |> order_by([entry], asc: entry.entry_date, asc: entry.inserted_at)
    |> preload(:lines)
    |> Repo.all()
  end

  def create_journal_entry(%Organization{} = organization, attrs, lines, opts \\ [])
      when is_list(lines) do
    attrs = stringify_keys(attrs)

    with {:ok, entry_date} <- journal_entry_date(attrs),
         {:ok, period} <- writable_period_for_journal(organization, entry_date),
         :ok <- validate_balanced_lines(lines) do
      entry_attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("period_id", period.id)
        |> Map.put("entry_date", entry_date)
        |> Map.put_new("status", "posted")
        |> Map.put_new("posted_at", DateTime.utc_now(:second))
        |> maybe_put_user_id(opts)

      Multi.new()
      |> Multi.insert(:entry, JournalEntry.changeset(%JournalEntry{}, entry_attrs))
      |> Multi.run(:lines, fn repo, %{entry: entry} ->
        insert_journal_lines(repo, organization, entry, lines)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{entry: entry}} -> {:ok, Repo.preload(entry, :lines)}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  def trial_balance(%Organization{} = organization, from_date, to_date) do
    JournalLine
    |> join(:inner, [line], entry in JournalEntry, on: entry.id == line.journal_entry_id)
    |> where([line, entry], line.organization_id == ^organization.id)
    |> where([_line, entry], entry.organization_id == ^organization.id)
    |> where([_line, entry], entry.status == "posted")
    |> where([_line, entry], entry.entry_date >= ^from_date and entry.entry_date <= ^to_date)
    |> group_by([line], [line.account_code, line.account_name])
    |> order_by([line], asc: line.account_code)
    |> select([line], %{
      account_code: line.account_code,
      account_name: line.account_name,
      debit_usd: coalesce(sum(line.debit_usd), 0),
      credit_usd: coalesce(sum(line.credit_usd), 0)
    })
    |> Repo.all()
  end

  defp period_event_changeset(period, event_type, from_status, to_status, opts) do
    PeriodEvent.changeset(%PeriodEvent{}, %{
      organization_id: period.organization_id,
      period_id: period.id,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      user_id: Keyword.get(opts, :user_id),
      reason: Keyword.get(opts, :reason)
    })
  end

  defp status_change_attrs("closed", opts) do
    %{
      "closed_at" => DateTime.utc_now(:second),
      "closed_by_user_id" => Keyword.get(opts, :user_id)
    }
  end

  defp status_change_attrs(_status, _opts), do: %{}

  defp event_type_for_status("open"), do: "reopened"
  defp event_type_for_status("closing"), do: "closing_started"
  defp event_type_for_status("closed"), do: "closed"
  defp event_type_for_status("locked"), do: "locked"

  defp maybe_filter_entry_dates(query, opts) do
    query
    |> maybe_filter_entry_date(:from, opts)
    |> maybe_filter_entry_date(:to, opts)
  end

  defp maybe_filter_entry_date(query, :from, opts) do
    case Keyword.get(opts, :from) do
      %Date{} = date -> where(query, [entry], entry.entry_date >= ^date)
      _value -> query
    end
  end

  defp maybe_filter_entry_date(query, :to, opts) do
    case Keyword.get(opts, :to) do
      %Date{} = date -> where(query, [entry], entry.entry_date <= ^date)
      _value -> query
    end
  end

  defp journal_entry_date(%{"entry_date" => %Date{} = date}), do: {:ok, date}

  defp journal_entry_date(%{"entry_date" => date}) when is_binary(date) do
    Date.from_iso8601(date)
  end

  defp journal_entry_date(_attrs), do: {:error, :entry_date_required}

  defp writable_period_for_journal(%Organization{} = organization, %Date{} = date) do
    case period_for_date(organization, date) do
      nil -> {:error, :accounting_period_required}
      %Period{status: status} = period when status in ["open", "closing"] -> {:ok, period}
      %Period{} -> {:error, :accounting_period_closed}
    end
  end

  defp validate_balanced_lines(lines) do
    with :ok <- validate_minimum_lines(lines),
         {:ok, debit_total, credit_total} <- journal_line_totals(lines) do
      if Decimal.equal?(debit_total, credit_total) and Decimal.compare(debit_total, 0) == :gt do
        :ok
      else
        {:error, :journal_entry_not_balanced}
      end
    end
  end

  defp validate_minimum_lines(lines) when length(lines) >= 2, do: :ok
  defp validate_minimum_lines(_lines), do: {:error, :journal_entry_requires_two_lines}

  defp journal_line_totals(lines) do
    Enum.reduce_while(lines, {:ok, Decimal.new(0), Decimal.new(0)}, fn attrs,
                                                                       {:ok, debit_total,
                                                                        credit_total} ->
      attrs = stringify_keys(attrs)

      with {:ok, debit} <- decimal_from_attrs(attrs, "debit_usd"),
           {:ok, credit} <- decimal_from_attrs(attrs, "credit_usd") do
        {:cont, {:ok, Decimal.add(debit_total, debit), Decimal.add(credit_total, credit)}}
      else
        :error -> {:halt, {:error, :invalid_journal_line_amount}}
      end
    end)
  end

  defp decimal_from_attrs(attrs, key) do
    attrs
    |> Map.get(key, 0)
    |> Decimal.cast()
  end

  defp maybe_put_user_id(attrs, opts) do
    case Keyword.get(opts, :user_id) do
      nil -> attrs
      user_id -> Map.put(attrs, "posted_by_user_id", user_id)
    end
  end

  defp insert_journal_lines(repo, organization, entry, lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {attrs, line_no}, {:ok, inserted_lines} ->
      attrs =
        attrs
        |> stringify_keys()
        |> Map.put("organization_id", organization.id)
        |> Map.put("journal_entry_id", entry.id)
        |> Map.put("line_no", line_no)

      case repo.insert(JournalLine.changeset(%JournalLine{}, attrs)) do
        {:ok, line} -> {:cont, {:ok, [line | inserted_lines]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, inserted_lines} -> {:ok, Enum.reverse(inserted_lines)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
