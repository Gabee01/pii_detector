defmodule PIIDetectorWeb.PageController do
  use PIIDetectorWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home,
      layout: false,
      slack_invite:
        "https://join.slack.com/t/jumpchallenge/shared_invite/zt-32y4fno6v-qJQ6rKU0qMO7yYa44FlR0w",
      notion_url: "https://www.notion.so/JUMP-PII-PROD-1cd30e6a7e4c8020b789f0dfa6285117?pvs=4"
    )
  end
end
