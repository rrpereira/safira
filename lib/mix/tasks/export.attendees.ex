defmodule Mix.Tasks.Export.Attendees do
    use Mix.Task
  
    def run(_) do
      Mix.Task.run "app.start"

      IO.puts "UUID,Name,Email"
      Enum.each(
        Safira.Accounts.list_active_attendees,
        fn a -> 
          IO.puts "#{a.id},#{a.name},#{Safira.Accounts.get_user!(a.user_id).email}"
        end
      )
    end
  end