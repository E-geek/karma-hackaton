server = require './lib/server'

assets = null
server.getAssets (data) ->
  assets = data
  return

module.exports = (io) -> io.on 'connection', (socket) ->
  USER_SID = Math.random().toString()
  login = null
  pass = null
  user = null

  socket.emit 'handshake', { sid: USER_SID }
  validate = (data) ->
    if data.sid isnt USER_SID
      socket.end()
      console.error "SID WAS CHANGED!!!"
      return no
    return yes
  socket
  .on 'handshake', (data) ->
    return unless validate data
    console.log "handshake success"
    return
  .on 'auth', (data) ->
    return unless validate data
    server.checkAuth data.login, data.pass, (err, ok) ->
      if err?
        socket.emit 'error', 'some login error'
        return
      if ok
        socket.emit 'auth', 'approve'
        login = data.login
        pass = data.pass
        server.getUserByName login, (err, data) ->
          user = data
          return
      else
        socket.emit 'auth', 'reject'
    return
  .on 'req', (data) ->
    return unless validate data
    switch data.type
      when 'balances'
        getBalance socket, user
      when 'history'
        getHistory data.limit, socket, user
      when 'send'
        sendMoney data, socket, user, pass
    return

sendMoney = (data, socket, user, pass) ->
  if user is null
    socket.emit 'res',
      type: 'send'
      error: 'no auth'
    return
  server.tryTransaction user.name, data.to, data.volume, pass, (err, data) ->
    if err?
      console.error 'SEND has fail', err
      socket.emit 'res',
        type: 'send'
        error: err
      return
    socket.emit 'res',
      type: 'send'
      result: data
    return
  return


getBalance = (socket, user) ->
  if user is null
    socket.emit 'res',
      type: 'balances'
      error: 'no auth'
    return
  server.getUserBalances user.id, (err, balances) ->
    if err?
      socket.emit 'res',
        type: 'balances'
        error: err
      return
    for balance in balances
      balance.human = server.humanisationAmount balance
    socket.emit 'res',
      type: 'balances'
      result: balances
  return # getBalance

getHistory = (limit, socket, user) ->
  if user is null
    socket.emit 'res',
      type: 'history'
      error: 'no auth'
    return
  limit = limit|0
  if limit < 1
    limit = 1
  else if limit > 100
    limit = 100
  server.getHistory user.id, limit, (err, history) ->
    if err?
      socket.emit 'res',
        type: 'history'
        error: err
      return
    socket.emit 'res',
      type: 'history'
      result: history
  return # getHistory
