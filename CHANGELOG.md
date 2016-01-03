# v2.0.0

* Breaking Change - Remove support for matchhistory-v2.2.
* Add support for matchlist-v2.2.
* If you want to use Promises, you no longer need to call the `blahBlahAsync` version of a command - instead callbacks
  are now optional, and any function which takes a callback will return a Promise if no callback is supplied.
* Bug fixes.
