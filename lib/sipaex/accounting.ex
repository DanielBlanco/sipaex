defmodule Sipaex.Accounting do
  @moduledoc """
  Accounting calendars and period lifecycle.

  This context owns the cross-module rules that decide whether an effective
  financial date belongs to an open, closing, closed, or locked period.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sipaex.Accounting.FiscalYear
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

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
