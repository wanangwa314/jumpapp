defmodule JumpappWeb.ErrorJSONTest do
  use JumpappWeb.ConnCase, async: true

  test "renders 404" do
    assert JumpappWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert JumpappWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
