defmodule PiiDetectorWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  test "renders 404" do
    assert PiiDetectorWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert PiiDetectorWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
