defmodule MagicAuth.Repo do
  alias Ecto.Multi

  def transaction(%Multi{} = multi) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().transaction(multi, opts)
  end

  def all(query) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().all(query, opts)
  end

  def get_by(queryable, clauses) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().get_by(queryable, clauses, opts)
  end

  def delete!(struct_or_changeset) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().delete!(struct_or_changeset, opts)
  end

  def insert!(struct_or_changeset) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().insert!(struct_or_changeset, opts)
  end

  def one(query) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().one(query, opts)
  end

  def delete_all(query) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().delete_all(query, opts)
  end

  def get(schema, id) do
    opts = MagicAuth.Config.repo_opts()
    MagicAuth.Config.repo_module().get(schema, id, opts)
  end

  def get_user(id) do
    MagicAuth.Config.get_user().(id)
  end
end
