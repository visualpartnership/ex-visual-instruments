defmodule Atlas do
  @moduledoc """
  Main module to make transactions through the authorizer.
  """
  alias Atlas.Authorizer

  @doc"""
  Main function to expose the authorizer functionality.

  You should provide an account and a transaction.
  The Authorizer will validate the transaction and it will apply or reject the operation.
  """
  def apply_transaction(account, transaction) do
    Authorizer.authorize_transaction(account, transaction)
  end

end
