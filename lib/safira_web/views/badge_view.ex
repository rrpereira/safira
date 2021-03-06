defmodule SafiraWeb.BadgeView do
  use SafiraWeb, :view
  alias SafiraWeb.BadgeView
  alias SafiraWeb.AttendeeView
  alias Safira.Avatar

  def render("index.json", %{badges: badges}) do
    %{data: render_many(badges, BadgeView, "badge.json")}
  end

  def render("show.json", %{badge: badge}) do
    %{data: render_one(badge, BadgeView, "badge_show.json")}
  end

  def render("badge.json", %{badge: badge}) do
    %{
      id: badge.id,
      name: badge.name,
      description: badge.description,
      avatar: Avatar.url({badge.avatar, badge}, :original),
      begin: badge.begin,
      end: badge.end,
      type: badge.type,
      tokens: badge.tokens,
    }
  end

  def render("badge_show.json", %{badge: badge}) do
    %{
      id: badge.id,
      name: badge.name,
      description: badge.description,
      avatar: Avatar.url({badge.avatar, badge}, :original),
      begin: badge.begin,
      end: badge.end,
      type: badge.type,
      tokens: badge.tokens,
      attendees: render_many(badge.attendees, AttendeeView, "attendee_simple.json")
    }
  end
end
