defmodule AtlasTest do
  use ExUnit.Case
  alias Atlas.Account
  alias Atlas.Transaction

  describe "Business Scenarios" do
    test "No transaction should be accepted without a properly initialized account" do
      account = :not_initialized
      transaction = %Transaction{}
      response = Atlas.apply_transaction(account, transaction)
      assert response == {:error, :not_initialized}
    end

    test "No transaction should be accepted when the card is not active" do
      account = %Account{active: false}
      transaction = %Transaction{}
      response = Atlas.apply_transaction(account, transaction)
      assert response == {:error, :card_not_active}
    end

    test "The transaction amount should not exceed the available limit" do
      account = %Account{active: true, available_limit: 1000}
      transaction = %Transaction{amount: 2000}
      response = Atlas.apply_transaction(account, transaction)

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

      {response, account} = Atlas.apply_transaction(account, transaction)
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

      {response, account} = Atlas.apply_transaction(account, transaction)
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
      {response, account} = Atlas.apply_transaction(account, transaction)
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

      {response, account} = Atlas.apply_transaction(account, transaction)
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

      {response, account} = Atlas.apply_transaction(account, transaction)
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

      {response, account} = Atlas.apply_transaction(account, transaction)
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

      {response, account} = Atlas.apply_transaction(account, transaction)
      assert response == :ok
      assert account.available_limit == 900
    end
  end
end
