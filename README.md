
<img width="1152" alt="image" src="https://user-images.githubusercontent.com/17634377/210700146-0c5de1bf-115f-4a26-8020-36b8cdb09284.png">

# Visual Instruments Workshop

This app is an example just for show how to illustrate software components.

<details>
  <summary> Atlas </summary>
  
  > Atlas is an authorizer flow for transactions. It's just an application example.
  
  ## Important Terms
  
  - `Account`: It's the only account available, this entity will save some information: `active`, `available limit`, `violations`, and `authorized transactions`.
  - `Transaction`: This will affect the account available params through be processed in the authorizer: `merchant`, `amount`, `time`.
  - `Authorizer`: This module will update the `account` by process `transactions`. This module includes some business rules to keep in mind.
  
  ## Authorizer Rules
  
- No transaction should be accepted without a properly initialized account: account-not-initialized
- No transaction should be accepted when the card is not active: card-not-active
- The transaction amount should not exceed the available limit: insufficient-limit
- There should not be more than 3 transactions on a 2-minute interval: high-frequency-small-interval (the input order cannot be relied upon since transactions can eventually be out of order respectively to their times)
- There should not be more than 1 similar transactions (same amount and merchant) in a 2 minutes interval: doubled-transaction

</details>
