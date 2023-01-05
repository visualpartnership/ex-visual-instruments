defmodule Atlas.Account do
  defstruct active: false, available_limit: nil, violations: [], authorized_transactions: []
end
