### Sending Ether (transfer, send, call)

#### How to send Ether?

You can send Ether to other contracts by

* `transfer` (2300 gas, throws error)
* `send` (2300 gas, returns bool)
* `call` (forward all gas or set gas, returns bool)

#### How to receive Ether?

A contract receiving Ether must have at least one of the functions below

* `receive() external payable`
* `fallback() external payable`

`receive()` is called if `msg.data` is empty, otherwise `fallback()` is called.

#### Which method should you use?

`call` in combination with re-entrancy guard is the recommended method to use after December 2019.

Guard against re-entrancy by

* making all state changes before calling other contracts
* using re-entrancy guard modifier

##### Fallback
`fallback` is a special function that is executed either when

* a function that does not exist is called or
* Ether is sent directly to a contract but `receive()` does not exist or `msg.data` is not empty
* `fallback` can optionally take `bytes` for input and output
`fallback` has a 2300 gas limit when called by `transfer` or `send`.

##### Call

`call` is a low level function to interact with other contracts.

This is the recommended method to use when you're just sending Ether via calling the `fallback` function.

However it is not the recommend way to call existing functions.

Few reasons why low-level call is not recommended

* Reverts are not bubbled up
* Type checks are bypassed
* Function existence checks are omitted

##### Delegatecall
`delegatecall` is a low level function similar to call.

When contract `A` executes `delegatecall` to contract `B`, `B`'s code is executed

with contract `A`'s storage, `msg.sender` and `msg.value`.