# ChordProtocol

## Description
A simulation of chord protocol for dristibuted system using actor model in Elixir.
The peer to peer to network is stabilised as nodes continue to join and stabilize.
Maximum number of nodes tried - 1000

### Project Execution – 
mix run --no-halt proj3.exs 100 20

### usage:  mix run --no-halt proj3.exs <n> <m>
Where 'n' is the number of peers to be created in the peer to peersystem and 'm' the number of requests each peer has to make.  When all peers performed that many requests, the program can exit.  Each peer should send a request/second.

### Output:
Print the average number of hops (node connections) that have to be traversed to deliever a message.


