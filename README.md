# Honeypot for Router Backdoor (TCP-32764)

This is a first try to mock the router backdoor "TCP32764" found in several router firmwares at the end of 2013. The POC of the backdoor is located at this [repository](https://github.com/elvanderb/TCP-32764).

## A note

This honeypot is not fully compatible to the real backdoor. However, we try to response positive answers for well known tests. Said this, both the `poc.py` and the web test from [Heise](http://www.heise.de/security/dienste/portscan/test/go.shtml?scanart=3) recognize this being a real backdoor.

Do not complain about any actions or problems after using this piece of code. Relax, take the time, read it first, and then try it on your own.

## Dependencies

NodeJS

## How to use (easy start)

1. `git clone https://github.com/knalli/honeypot-for-tcp-32764.git` && `cd honeypot-for-tcp-32764`
2. `npm install`
3. `node_modules/.bin/coffee server.coffee`

## How to use (daemon)

There are two user scripts defined in the `package.json` which instruments [Forever](https://github.com/nodejitsu/forever). Simply use `npm start` to start the server and `npm stop` to stop the server. The flag `-w` is used therefor any file changes will effectily restart the server in a second.

## Contribution

Yes, if you like.

## License

Free for all. 

MIT