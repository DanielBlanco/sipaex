defmodule Sipaex.Inventory do
  @moduledoc """
  Product catalog shared by purchases, sales, inventory, and future production flows.
  """

  import Ecto.Query

  alias Sipaex.Inventory.Product
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  def product_types do
    [
      {"Materia prima", "raw_material"},
      {"Producto terminado", "finished_good"},
      {"Producto para reventa", "resale_good"},
      {"Servicio", "service"},
      {"Suministro", "supply"},
      {"Empaque", "packaging"}
    ]
  end

  def purchasable_types, do: ~w(raw_material resale_good service supply packaging)
  def sellable_types, do: ~w(finished_good resale_good service)

  def settings(organization \\ first_organization!()) do
    organization = Repo.preload(organization, :base_currency)

    %{
      organization: organization,
      products: list_products(organization),
      product_types: product_types()
    }
  end

  def list_products(%Organization{} = organization) do
    Product
    |> where([product], product.organization_id == ^organization.id)
    |> order_by([product], asc: product.code)
    |> Repo.all()
  end

  def list_active_products(%Organization{} = organization) do
    Product
    |> where([product], product.organization_id == ^organization.id)
    |> where([product], product.active)
    |> order_by([product], asc: product.code)
    |> Repo.all()
  end

  def list_purchasable_products(%Organization{} = organization) do
    Product
    |> where([product], product.organization_id == ^organization.id)
    |> where([product], product.active)
    |> where([product], product.product_type in ^purchasable_types())
    |> order_by([product], asc: product.code)
    |> Repo.all()
  end

  def create_product(attrs, organization \\ first_organization!()) do
    %Product{}
    |> Product.changeset(Map.put(attrs, "organization_id", organization.id))
    |> Repo.insert()
  end

  def display_type("raw_material"), do: "Materia prima"
  def display_type("finished_good"), do: "Producto terminado"
  def display_type("resale_good"), do: "Producto para reventa"
  def display_type("service"), do: "Servicio"
  def display_type("supply"), do: "Suministro"
  def display_type("packaging"), do: "Empaque"
  def display_type(type), do: type

  defp first_organization! do
    Organization
    |> order_by([organization], asc: organization.inserted_at)
    |> preload(:base_currency)
    |> Repo.one!()
  end
end
