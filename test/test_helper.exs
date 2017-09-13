ExUnit.start(exclude: [:system])
# These files have to be required here, since the code requires ExUnit
# application to be running while loading (use ExUnit.Case).
# But first we need to load Helper.Macros module, since the other ones
# use the macros defined in it.
Code.require_file "helper/macros.ex", __DIR__

{:ok, files} = File.ls("./test/helper")
Enum.each files, fn(file) ->
  Code.require_file "helper/#{file}", __DIR__
end

Code.require_file "fennec/udp/auth_template.ex", __DIR__

{:ok, _pid} = Helper.PortMaster.start_link()
