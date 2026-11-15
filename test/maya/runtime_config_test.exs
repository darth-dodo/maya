defmodule Maya.RuntimeConfigTest do
  # Changes OS env vars, so it cannot run beside other tests.
  use ExUnit.Case, async: false

  @vars ~w(DATABASE_URL SECRET_KEY_BASE BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD)

  setup do
    saved = Map.new(@vars, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end)

    System.put_env("DATABASE_URL", "ecto://u:p@localhost/maya")
    System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))
    System.put_env("BASIC_AUTH_USERNAME", "friend")
    System.put_env("BASIC_AUTH_PASSWORD", "s3cret-pass")
    :ok
  end

  defp prod_config, do: Config.Reader.read!("config/runtime.exs", env: :prod)

  test "prod reads the login from the env" do
    assert prod_config()[:maya][:basic_auth] == [username: "friend", password: "s3cret-pass"]
  end

  for var <- ~w(BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD) do
    test "prod refuses to boot without #{var}" do
      System.delete_env(unquote(var))
      error = assert_raise RuntimeError, &prod_config/0
      assert error.message =~ unquote(var)
    end

    test "prod refuses to boot with an empty #{var}" do
      System.put_env(unquote(var), "")
      error = assert_raise RuntimeError, &prod_config/0
      assert error.message =~ unquote(var)
      refute error.message =~ "s3cret-pass"
    end
  end
end
