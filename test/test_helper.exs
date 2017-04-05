ExUnit.start(exclude: [:system])

{:ok, files} = File.ls("./test/helper")

Enum.each files, fn(file) ->
  Code.require_file "helper/#{file}", __DIR__
end
