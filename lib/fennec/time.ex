defmodule Fennec.Time do
  @moduledoc false
  # Abstract time(r)-related functions for mocking / overriding them in tests.
  # This should allow for testing timeouts without actually waiting.

  @type seconds :: integer

  @spec system_time(System.time_unit) :: integer
  def system_time(unit) do
    System.system_time(unit)
  end

end
