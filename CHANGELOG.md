# v2.0.2

* Fix error that prevented summoner names with non-ascii characters from being found.
* Add TEAM_BUILDER_DRAFT_RANKED_5x5 to list of default match types returned when searching for match list for a
  summoner.

# v2.0.1

* Fix critical bug in how requests are queued.

# v2.0.0

* Breaking Change - Remove support for matchhistory-v2.2.
* Breaking Change - Removed `defaultRegion` option from Client.  The following methods no longer take `region` as an
  option but instead now take it as the first parameter:
    * `getRecentGamesForSummoner()`
    * `recentGameToMatch()`
    * `getChampions()`
    * `getChampionById()`
    * `getChampionByKey()`
    * `getChampionByName()`
    * `getItems()`
    * `getItemById()`
    * `getVersions()`        
    * `getMatch()`
    * `populateMatch()`
    * `getSummonersByName()`
    * `getSummonersById()`
    * `getSummonerNames()`
    * `getSummonerMasteries()`
    * `getSummonerRunes()`
    * `getTeamsBySummoner()`
    * `getTeams()`
    * `getTeam()`

* Breaking Change - If you want to use Promises, you no longer need to call the `blahBlahAsync` version of a command -
  instead callbacks are now optional, and any function which takes a callback will return a Promise if no callback is
  supplied.
* Add support for matchlist-v2.2.
* Bug fixes.
