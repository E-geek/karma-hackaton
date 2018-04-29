console.log("Hi!");
(function(){
  var socket, sid;
  var done = false, histored;
  socket = io.connect('http://localhost:8081');
  socket
  .on('handshake', function(data) {
    sid = data.sid;
    socket.emit('handshake', {sid: sid});

  })
  .on('error', function (err) {
    console.error(err);
  })
  .on('auth', function (data) {
    console.log("Auth data: '" + data + "'");
    if (data === 'approve') {
      socket.emit('req', {
        sid: sid,
        type: 'balances'
      });
      socket.emit('req', {
        sid: sid,
        type: 'history',
        limit: 10
      });
    }
  })
  .on('res', function (data) {
    var head, value, html;
    console.log("RES data: ", data);
    if (data.type === 'balances') {
      if (done) {
        document.querySelector('.js-auth').style.display = 'none';
      }
      done = true;
      head = '<h4 class="mdl-cell mdl-cell--4-col mdl-cell--4-col-tablet mdl-cell--4-col-phone">Баланс (#NAME):</h4>';
      value = '<h4 class="mdl-cell mdl-cell--8-col mdl-cell--4-col-tablet mdl-cell--4-col-phone">#VALUE</h4>';
      html = '';
      for (var i = 0, ref = data.result, len = ref.length; i < len; i++) {
        html += head.replace('#NAME', ref[i].human.name);
        html += value.replace('#VALUE', ref[i].human.quantity);
      }
      document.querySelector('.js-active-balance').innerHTML = html;
      return;
    }

    if (data.type === 'history') {
      if (done) {
        document.querySelector('.js-auth').style.display = 'none';
      }
      done = true;
      head = '<tr><td class="mdl-data-table__cell--non-numeric">#TYPE</td><td>#VALUE</td><td>#ID</td></tr>';
      html = '';
      for (var i = 0, ref = data.result, len = ref.length; i < len; i++) {
        value = ref[i];
        html += head
          .replace('#TYPE', value.type === 'send' ? '-' : '+')
          .replace('#VALUE', value.amountHuman.quantity)
          .replace('#ID', value.blockNum);
      }
      document.querySelector(!histored ? '.js-history-simple' : '.js-history-full').innerHTML = html;
      if (!histored) {
        socket.emit('req', {
          sid: sid,
          type: 'history',
          limit: 100
        });
      }
      histored = true;
      return;
    }
  });

  var loginForm, submitButton;
  loginForm = document.querySelector('.js-login');
  loginForm.onsubmit = function (e) {
    e.preventDefault();
    socket.emit('auth', {
      sid: sid,
      login: loginForm[0].value,
      pass: loginForm[1].value
    });
    return false;
  };
  submitButton = loginForm.querySelector('.js-submit');
  submitButton.onclick = loginForm.onsubmit;
})();