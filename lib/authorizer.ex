defmodule Atlas.Authorizer do
  alias Atlas.Account

  def authorize_transaction(account, transaction) do
    {account, transaction}
    |> verify_initialized_account()
    |> verify_active_account()
    |> verify_limit()
    |> verify_transactions_interval()
    |> verify_double_transaction()
    |> apply_transaction()
  end

  @doc "This verify if the account is already initialized."
  def verify_initialized_account({:not_initialized, _transaction}), do: {:error, :not_initialized}
  def verify_initialized_account({account, transaction}), do: {account, transaction}

  @doc "This verify if the account isn't initialized or continue to verify if the card is active"
  def verify_active_account({:error, :not_initialized}), do: {:error, :not_initialized}

  def verify_active_account({account, transaction}) do
    is_active_card({account.active, account, transaction})
  end

  def is_active_card({false, _account, _transaction}), do: {:error, :card_not_active}
  def is_active_card({true, account, transaction}), do: {account, transaction}

  @doc "This verify if there any error or continue to authorize the transaction"
  def verify_limit({:error, error_msg}), do: {:error, error_msg}

  def verify_limit({account, transaction}) do
    check_limit({account.available_limit > transaction.amount, account, transaction})
  end

  def check_limit({false, account, _transaction}), do: {:error, :insufficient_limit, account}
  def check_limit({true, account, transaction}), do: {account, transaction}

  def verify_transactions_interval({:error, error_msg}), do: {:error, error_msg}
  def verify_transactions_interval({:error, error_msg, account}), do: {:error, error_msg, account}

  def verify_transactions_interval({account, transaction}) do
    interval120_validation = is_in_interval(account.authorized_transactions, transaction)

    case interval120_validation do
      :not_in_interval -> {:error, :high_frequency_small_interval, account}
      :in_interval -> {account, transaction}
      :without_transactions -> {:without_transactions, account, transaction}
    end
  end

  def is_in_interval([], _transaction), do: :without_transactions
  def is_in_interval([_h | tail], _transaction) when tail == [], do: :without_transactions
  def is_in_interval([_ | [_ | tail]], _transaction) when tail == [], do: :without_transactions

  def is_in_interval(transactions_authorized, _transaction) do
    [third | [second | [first | _tail]]] = transactions_authorized

    # validate first and third
    diff_third_first_transactions = NaiveDateTime.diff(third.time, first.time)
    # validate second and third
    diff_second_first_transactions = NaiveDateTime.diff(second.time, first.time)

    validations = {diff_third_first_transactions < 120, diff_second_first_transactions < 120}

    case validations do
      {true, true} -> :not_in_interval
      _ -> :in_interval
    end
  end

  def verify_double_transaction({:error, msg}), do: {:error, msg}
  def verify_double_transaction({:error, msg, account}), do: {:error, msg, account}

  def verify_double_transaction({:without_transactions, account, transaction}) do
    looking_for_double_transactions(account, account.authorized_transactions, transaction)
  end

  def verify_double_transaction({account, transaction}) do
    [third_transaction | [second_transaction | _]] = account.authorized_transactions
    looking_for_double_transactions(account, [third_transaction, second_transaction], transaction)
  end

  def looking_for_double_transactions(account, transactions, transaction) do
    transaction_double =
      Enum.find(
        transactions,
        fn t ->
          t.amount == transaction.amount &&
            t.merchant == transaction.merchant
        end
      )

    case transaction_double do
      nil -> {account, transaction}
      _ -> {:error, :doubled_transaction, account}
    end
  end

  def apply_transaction({:error, msg}), do: {:error, msg}
  def apply_transaction({:error, msg, account}), do: {:error, %{account | violations: [msg]}}

  def apply_transaction({account, transaction}) do
    authorized_transactions = [transaction] ++ account.authorized_transactions
    available_limit_updated = account.available_limit - transaction.amount

    {:ok,
     %{
       account
       | authorized_transactions: authorized_transactions,
         available_limit: available_limit_updated
     }}
  end

  def validate_account_initialized(:not_initialized, available_limit) do
    active_account = %Account{
      active: true,
      available_limit: available_limit
    }

    {active_account, active_account}
  end

  def validate_account_initialized(account_initialized, _available_limit) do
    account = %{account_initialized | violations: [:account_already_initialized]}
    {account, account_initialized}
  end
end
