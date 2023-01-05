defmodule Atlas.AuthorizerTest do
  use ExUnit.Case, async: false
  alias Atlas.Account
  alias Atlas.Authorizer
  alias Atlas.Transaction

  describe "Authorizer flows" do
    test "If there are a not initialized account I expect an error atom" do
      account_not_initialized = :not_initialized
      transaction = %Transaction{amount: 100}

      response_not_initialized =
        Authorizer.verify_initialized_account({account_not_initialized, transaction})

      assert response_not_initialized == {:error, :not_initialized}
    end

    test "If there are a initialized account I expect the account and transaction" do
      account_initialized = %Account{}
      transaction = %Transaction{amount: 100}

      {response_init, state_init} =
        Authorizer.verify_initialized_account({account_initialized, transaction})

      assert response_init == account_initialized
      assert state_init == transaction
    end

    test "If the verify_active_card recibes an error I expected an error" do
      response = Authorizer.verify_active_account({:error, :not_initialized})
      assert response == {:error, :not_initialized}
    end

    test "If the verify_active_account recibes an inactive card I expect the account with the violations array" do
      account_inactive = %Account{active: false}
      transaction = %Transaction{}
      {response, msg} = Authorizer.verify_active_account({account_inactive, transaction})
      assert response == :error
      assert msg == :card_not_active
    end

    test "If the verify_active_account recibes an active card I expected the account and transaction" do
      account_active = %Account{active: true}
      transaction = %Transaction{amount: 100}
      {account, response} = Authorizer.verify_active_account({account_active, transaction})
      assert account == account_active
      assert response == transaction
    end

    test "If the verify_limit recives an error is because the card not be initialized" do
      resp1 = Authorizer.verify_limit({:error, :not_initialized})
      resp2 = Authorizer.verify_limit({:error, :card_not_active})
      assert resp1 == {:error, :not_initialized}
      assert resp2 == {:error, :card_not_active}
    end

    test "If the  verify_limit recibes :not_allow is because the account is inactive" do
      resp = Authorizer.verify_limit({:error, :card_not_active})
      assert resp == {:error, :card_not_active}
    end

    test "If the verify_limit recibes a transaction more higher than the limit I expected the account with violations" do
      account = %Account{available_limit: 500}
      transaction = %Transaction{amount: 700}
      response = Authorizer.verify_limit({account, transaction})
      assert response == {:error, :insufficient_limit, account}
    end

    test "If there an account without historic transactions, continue without errors" do
      account1 = %Account{available_limit: 1000, authorized_transactions: []}
      transaction1 = %Transaction{amount: 700}
      response1 = Authorizer.verify_transactions_interval({account1, transaction1})
      assert response1 == {:without_transactions, account1, transaction1}
    end

    test "Accept until 3 transactions without errors" do
      transaction1 = %Transaction{amount: 700}
      account1 = %Account{available_limit: 1000, authorized_transactions: [transaction1]}
      response1 = Authorizer.verify_transactions_interval({account1, transaction1})

      account2 = %Account{
        available_limit: 1000,
        authorized_transactions: [transaction1, transaction1]
      }

      response2 = Authorizer.verify_transactions_interval({account2, transaction1})

      assert response1 == {:without_transactions, account1, transaction1}
      assert response2 == {:without_transactions, account2, transaction1}
    end

    test "Validate if there enough transactions in 120 seconds" do
      transaction1 = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:10.661001]}
      transaction2 = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:20.661001]}
      transaction3 = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:30.661001]}
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}

      resp =
        Authorizer.is_in_interval(
          [transaction3, transaction2, transaction1],
          transaction_to_authorize
        )

      assert resp == :not_in_interval
    end

    test "Validate if there aren't enough transactions in 120 seconds" do
      transaction1 = %Transaction{amount: 700, time: ~N[2019-12-26 05:40:10.661001]}
      transaction2 = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:20.661001]}
      transaction3 = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:30.661001]}
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}

      resp =
        Authorizer.is_in_interval(
          [transaction3, transaction2, transaction1],
          transaction_to_authorize
        )

      assert resp == :in_interval
    end

    test "Validate if there aren't transactions in 120 seconds" do
      transaction1 = %Transaction{amount: 700, time: ~N[2019-12-26 05:40:10.661001]}
      transaction2 = %Transaction{amount: 700, time: ~N[2019-12-26 05:44:20.661001]}
      transaction3 = %Transaction{amount: 700, time: ~N[2019-12-26 05:48:30.661001]}
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}

      resp =
        Authorizer.is_in_interval(
          [transaction3, transaction2, transaction1],
          transaction_to_authorize
        )

      assert resp == :in_interval
    end

    test "Validate if there aren't transactions, authorize the first" do
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}
      resp = Authorizer.is_in_interval([], transaction_to_authorize)
      assert resp == :without_transactions
    end

    test "Validate if there only one, authorize the transaction" do
      transaction1 = %Transaction{amount: 700, time: ~N[2019-12-26 05:40:10.661001]}
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}
      resp = Authorizer.is_in_interval([transaction1], transaction_to_authorize)
      assert resp == :without_transactions
    end

    test "Validate if there only two, authorize the transaction" do
      transaction1 = %Transaction{amount: 700, time: ~N[2019-12-26 05:40:10.661001]}
      transaction2 = %Transaction{amount: 700, time: ~N[2019-12-26 05:40:10.661001]}
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}
      resp = Authorizer.is_in_interval([transaction1, transaction2], transaction_to_authorize)
      assert resp == :without_transactions
    end

    test "Validate a set of transactions stored and a new one to be authorized" do
      transaction1 = %Transaction{time: ~N[2019-12-26 05:40:10.661001]}
      transaction2 = %Transaction{time: ~N[2019-12-26 05:40:20.661001]}
      transaction3 = %Transaction{time: ~N[2019-12-26 05:40:30.661001]}
      transaction4 = %Transaction{time: ~N[2019-12-26 05:43:10.661001]}
      transaction5 = %Transaction{time: ~N[2019-12-26 05:43:10.661001]}
      transactions = [transaction5, transaction4, transaction3, transaction2, transaction1]
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}
      resp = Authorizer.is_in_interval(transactions, transaction_to_authorize)
      assert resp == :in_interval
    end

    test "Validate a set of transactions stored and a new one to be not in interval" do
      transaction1 = %Transaction{time: ~N[2019-12-26 05:40:10.661001]}
      transaction2 = %Transaction{time: ~N[2019-12-26 05:40:20.661001]}
      transaction3 = %Transaction{time: ~N[2019-12-26 05:43:10.661001]}
      transaction4 = %Transaction{time: ~N[2019-12-26 05:43:20.661001]}
      transaction5 = %Transaction{time: ~N[2019-12-26 05:43:30.661001]}
      transactions = [transaction5, transaction4, transaction3, transaction2, transaction1]
      transaction_to_authorize = %Transaction{amount: 700, time: ~N[2019-12-26 05:43:40.661001]}
      resp = Authorizer.is_in_interval(transactions, transaction_to_authorize)
      assert resp == :not_in_interval
    end

    test "Verify if there aren't double transaction" do
      transaction1 = %Transaction{amount: 100, merchant: "Nubank"}
      transaction2 = %Transaction{amount: 200, merchant: "Nubank"}
      transaction_to_authorize = %Transaction{amount: 103, merchant: "Uber"}
      account = %Account{authorized_transactions: [transaction2, transaction1]}
      response = Authorizer.verify_double_transaction({account, transaction_to_authorize})
      assert response == {account, transaction_to_authorize}
    end

    test "Verify if there are double transaction" do
      transaction1 = %Transaction{amount: 100, merchant: "Nubank"}
      transaction2 = %Transaction{amount: 200, merchant: "Nubank"}
      transaction_to_authorize = %Transaction{amount: 100, merchant: "Nubank"}
      account = %Account{authorized_transactions: [transaction2, transaction1]}
      response = Authorizer.verify_double_transaction({account, transaction_to_authorize})
      assert response == {:error, :doubled_transaction, account}
    end

    test "Apply transaction and update available limit" do
      account = %Account{available_limit: 500, authorized_transactions: []}
      transaction = %Transaction{amount: 200}
      resp = Authorizer.apply_transaction({account, transaction})
      expected_account = %Account{available_limit: 300, authorized_transactions: [transaction]}
      assert resp == {:ok, expected_account}
    end
  end

  describe "Business Scenarios" do
    test "No transaction should be accepted without a properly initialized account" do
      account = :not_initialized
      transaction = %Transaction{}
      response = Authorizer.authorize_transaction(account, transaction)
      assert response == {:error, :not_initialized}
    end

    test "No transaction should be accepted when the card is not active" do
      account = %Account{active: false}
      transaction = %Transaction{}
      response = Authorizer.authorize_transaction(account, transaction)
      assert response == {:error, :card_not_active}
    end

    test "The transaction amount should not exceed the available limit" do
      account = %Account{active: true, available_limit: 1000}
      transaction = %Transaction{amount: 2000}
      response = Authorizer.authorize_transaction(account, transaction)

      assert response ==
               {:error,
                %Account{
                  active: true,
                  authorized_transactions: [],
                  available_limit: 1000,
                  violations: [:insufficient_limit]
                }}
    end

    test "There should not be more than 3 transactions on a 2-minute interval" do
      transaction1 = %Transaction{time: ~N[2019-12-26 05:40:10.661001], amount: 100}
      transaction2 = %Transaction{time: ~N[2019-12-26 05:40:20.661001], amount: 100}
      transaction3 = %Transaction{time: ~N[2019-12-26 05:40:30.661001], amount: 100}
      transaction = %Transaction{time: ~N[2019-12-26 05:43:30.661001], amount: 200}

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction3, transaction2, transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :error
      assert account.violations == [:high_frequency_small_interval]
    end

    test "There should not be more than 1 similar transactions" do
      transaction1 = %Transaction{
        time: ~N[2019-12-26 05:40:10.661001],
        amount: 100,
        merchant: "NubankA"
      }

      transaction2 = %Transaction{
        time: ~N[2019-12-26 05:40:20.661001],
        amount: 100,
        merchant: "NubankB"
      }

      transaction = %Transaction{
        time: ~N[2019-12-26 05:43:30.661001],
        amount: 100,
        merchant: "NubankB"
      }

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction2, transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :error
      assert account.violations == [:doubled_transaction]
    end

    test "Case A: Update an authorized transaction" do
      transaction = %Transaction{
        time: ~N[2019-12-26 05:43:30.661001],
        amount: 100,
        merchant: "Nubank"
      }

      account = %Account{active: true, available_limit: 1000, authorized_transactions: []}
      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end

    test "Case B: Update an authorized transaction" do
      transaction1 = %Transaction{
        time: ~N[2019-12-26 05:40:10.661001],
        amount: 100,
        merchant: "Uber"
      }

      transaction = %Transaction{
        time: ~N[2019-12-26 05:43:30.661001],
        amount: 100,
        merchant: "Nubank"
      }

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end

    test "Case C: Update an authorized transaction" do
      transaction1 = %Transaction{
        time: ~N[2019-12-26 05:40:10.661001],
        amount: 100,
        merchant: "Uber"
      }

      transaction2 = %Transaction{
        time: ~N[2019-12-26 05:43:20.661001],
        amount: 100,
        merchant: "Apple"
      }

      transaction = %Transaction{
        time: ~N[2019-12-26 05:43:30.661001],
        amount: 100,
        merchant: "Nubank"
      }

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction2, transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end

    test "Case D: Update an authorized transaction" do
      transaction1 = %Transaction{
        time: ~N[2019-12-26 05:40:10.661001],
        amount: 100,
        merchant: "Uber"
      }

      transaction2 = %Transaction{
        time: ~N[2019-12-26 05:43:10.661001],
        amount: 100,
        merchant: "Apple"
      }

      transaction3 = %Transaction{
        time: ~N[2019-12-26 05:43:20.661001],
        amount: 100,
        merchant: "Nikon"
      }

      transaction = %Transaction{
        time: ~N[2019-12-26 05:43:30.661001],
        amount: 100,
        merchant: "Nubank"
      }

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction3, transaction2, transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end

    test "Case E: Update an authorized transaction" do
      transaction1 = %Transaction{
        time: ~N[2019-12-26 05:40:10.661001],
        amount: 100,
        merchant: "Uber"
      }

      transaction2 = %Transaction{
        time: ~N[2019-12-26 05:43:10.661001],
        amount: 100,
        merchant: "Apple"
      }

      transaction3 = %Transaction{
        time: ~N[2019-12-26 05:43:20.661001],
        amount: 100,
        merchant: "Nikon"
      }

      transaction = %Transaction{
        time: ~N[2019-12-26 05:47:30.661001],
        amount: 100,
        merchant: "Nubank"
      }

      account = %Account{
        active: true,
        available_limit: 1000,
        authorized_transactions: [transaction3, transaction2, transaction1]
      }

      {response, account} = Authorizer.authorize_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end
  end
end
