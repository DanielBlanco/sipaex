defmodule SipaexWeb.PageControllerTest do
  use SipaexWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="login-form")
    assert html =~ ~s(action="/dashboard")
    assert html =~ "Iniciar sesión"
    assert html =~ "Correo electrónico"
  end

  test "GET /dashboard", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")
    html = html_response(conn, 200)

    assert html =~ ~s(id="app-dashboard")
    assert html =~ "Panel principal"
    assert html =~ "Módulos listos para construir"
  end
end
