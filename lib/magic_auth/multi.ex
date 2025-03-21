defmodule MagicAuth.Multi do
  def new, do: Ecto.Multi.new()

  def delete_all(multi, name, queryable_or_fun) do
    Ecto.Multi.delete_all(multi, name, queryable_or_fun, MagicAuth.Config.repo_opts())
  end

  def insert(multi, name, changeset_or_struct_or_fun) do
    Ecto.Multi.insert(multi, name, changeset_or_struct_or_fun, MagicAuth.Config.repo_opts())
  end
end
