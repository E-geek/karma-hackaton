exports.out = (err, data) ->
  if err?
    console.error "Error!\n", err
    return
  console.log data
  return

exports.last = null
exports.when = (data) ->
  exports.last = data
  return

exports.toHuman = (str, length, pattern = '0') ->
  str = '' + str
  str = pattern.repeat(length+1).slice(str.length) + str
  return str.slice(0,-length) + '.' + str.slice(-length)
