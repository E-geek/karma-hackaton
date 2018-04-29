{ Apis, ChainConfig } = require "karmajs-ws"
{ TransactionBuilder, Login, ChainStore } = require "karmajs"
help = require './help'

ChainConfig.networks.KarmaT =
  core_asset: 'KRMT',
  address_prefix: 'KRMT',
  chain_id: 'e81bea67cebfe8612010fc7c26702bce10dc53f05c57ee6d5b720bbe62e51bef'

ChainConfig.setPrefix 'KRMT'

queryDBWaitConnection = []
queryNetworkWaitConnection = []
connected = no
assetsStore = null

bd = (method, params..., cb) ->
  if connected
    console.log task = "run bd #{method}, [#{params.join(', ')}]"
    Apis.instance().db_api().exec method, params
      .then (result) ->
        cb null, result
        console.log "Done DB task: #{task}"
        return
      .catch (err) ->
        cb err
        return
  else
    console.log 'add DB task to queue'
    queryDBWaitConnection.push [method, params, cb]
  return # bd

network = (method, params..., cb) ->
  if connected
    console.log task = "run network #{method}, [#{params.join(', ')}]"
    Apis.instance().history_api().exec method, params
      .then (result) ->
        cb null, result
        console.log "Done NW task: #{task}"
        return
      .catch (err) ->
        cb err
        return
  else
    console.log 'add NW task to queue'
    queryNetworkWaitConnection.push [method, params, cb]
  return # bd

connect = ->
  Apis
    .instance("wss://testnet-node.karma.red", true)
    .init_promise
    .then (res) ->
      connected = yes
      console.log "connected to: #{res[0].network}"
      ChainStore.init().then ->
        console.log "ChainComplete"
        for query in queryDBWaitConnection
          bd query[0], query[1]..., query[2]
        return
        for query in queryNetworkWaitConnection
          network query[0], query[1]..., query[2]
        return
      return
    .catch (err) ->
      console.error err
      console.log 'retry connection after 10 seconds'
      setTimeout connect, 10000
      return
  return # connect

# if bd without params then update
getAssets = (cb) ->
  if cb
    if assetsStore
      process.nextTick ->
        cb assetsStore
        return
      return
    unless getAssets.queue
      getAssets.queue = [cb]
    else
      getAssets.queue.push cb
  bd 'list_assets', '*', 10, (err, assets) ->
    if err?
      console.error err
      handler() for handler in getAssets.queue
      getAssets.queue = []
      return
    assetsStore =
      byName: {}
      byId: {}
      byList: null
    byList = []
    for asset in assets
      byList.push
        id: asset.id
        name: asset.symbol
        precision: asset.precision
    byList = byList.sort (a, b) ->
      if a.id > b.id
        return 1
      else if a.id < b.id
        return -1
      return 0
    for asset2 in byList
      assetsStore.byName[asset2.name] = asset2
      assetsStore.byId[asset2.id] = asset2
    assetsStore.byList = byList
    if getAssets.queue
      for handler in getAssets.queue
        try
          handler assetsStore
        catch err
          console.log "getAssets error bd cb:\n", err
      getAssets.queue = []
    return # `bd` handler
  return # getAssets

getUserBalances = (id, cb) ->
  getAssets ->
    ids = assetsStore.byList.map (asset) -> asset.id
    bd 'get_account_balances', id, ids, cb
    return # `getAssets` handler
  return # getUserBalance

userCache =
  byName: new Map()
  byId: new Map()

getUserByName = (name, cb) ->
  user = userCache.byName.get name
  if user?
    process.nextTick -> cb null, user; return
    return # escape getUserName
  bd 'get_account_by_name', name, (err, data) ->
    if err? or data is null
      cb err, data
      return
    userCache.byName.set name, data
    userCache.byId.set data.id, data
    cb null, data
    return # `bd` handler
  return # getUserName

getUsersByIds = (ids, cb) ->
  result = new Map()
  miss = []
  for id in ids
    user = userCache.byId.get id
    if user
      result.set id, user
    else
      miss.push id
  if miss.length is 0
    process.nextTick -> cb null, result; return
    return # escape getUsersByIds
  bd 'get_accounts', miss, (err, data) ->
    if err?
      cb err, result
      return null
    for user2 in data
      userCache.byName.set user2.name, user2
      userCache.byId.set user2.id, user2
      result.set user2.id, user2
    cb null, result
    return # `bd` handler
  return # getUsesByIds

checkAuth = (name, pass, cb) ->
  getUserByName name, (err, data) ->
    if err?
      cb err
      return
    keys = Login.generateKeys name, pass
    cb null, data.options.memo_key is keys.pubKeys.active
    return
  return # checkAuth

humanisationAmount = (amount) ->
  asset = assetsStore.byId[amount.asset_id]
  quantity = help.toHuman amount.amount, asset.precision
  name = asset.name
  return { quantity, name }

getHistory = (accId, limit = 10, cb) ->
  network "get_account_history", accId, '1.11.0', limit,'1.11.0', (err, data) ->
    if err?
      cb err
      return
    history = []
    userIds = []
    for item in data when item.op[0] is 0
      op = item.op[1]
      opponent = if op.from is accId then op.to else op.from
      if opponent not in userIds
        userIds.push opponent
      history.push
        id: item.id
        blockNum: item.block_num
        type: if op.from is accId then 'send' else 'recv'
        opponent: opponent
        opponentName: ''
        amount: op.amount.amount
        amountHuman: humanisationAmount op.amount
        fee: op.fee.amount
        feeHuman: humanisationAmount op.fee
    getUsersByIds userIds, (err2, data2) ->
      if err2?
        cb err2, history
        return
      for step in history
        step.opponentName = data2.get(step.opponent).name
      cb null, history
      return # `getUsersByIds` handler
    return # `network` handler
  return # getHistory

tryTransaction = (cb) ->
  tr = new TransactionBuilder
  tr.add_type_operation 'transfer',
    fee:
      amount: 0
      asset_id: "1.3.0"
    from: "1.2.146"
    to: "1.2.21"
    amount: { amount: 50000, asset_id: "1.3.0" }
    memo:
      from: "KRMT6vmvqxRNWVkzbxGngwHd78RagUZKVe8Ws6CJ1QZpqrxZ5WKmRe"
      to: "KRMT54jpAy28X7dPrKKZzCibgUFgPH4cNAGuRmsxvzKqEzFyxwhzdS"
      nonce: 0
      message: ""
  tr.set_required_fees()
  .then ->
    keys = Login.generateKeys 'l0uter', 'hanter&bb+cc'
    tr.add_signer keys.privKeys.active, keys.pubKeys.active
    #tr.add_signer keys.privKeys.owner, keys.pubKeys.owner
    #tr.add_signer keys.privKeys.memo, keys.pubKeys.memo
    tr.get_potential_signatures()
    .then (ref) ->
      { pubkeys } = ref
      tr.get_required_signatures(pubkeys)
      .then ->
        tr.broadcast()
        .then (data) ->
          console.log "TR SUCCESS:\n", data
          return
        .catch (err) ->
          console.error "broadcast error:\n", err
          return
        return
      .catch (err) ->
        console.error "get_required_signatures error:\n", err
        return
    .catch (err) ->
      console.error "get_potential_signatures error:\n", err
      return
    return
  .catch (err) ->
    console.error "set_required_fees error:\n", err
    return
  return

do connect
do getAssets

module.exports = { bd, network, getAssets, getUserBalances,
  getUserByName, getUsersByIds, checkAuth, humanisationAmount,
  getHistory, tryTransaction, ChainStore }
