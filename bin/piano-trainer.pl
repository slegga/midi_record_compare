#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite;
use DateTime;
use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";

use Model::Action;

get '/' => 'index';

my $clients = {};

websocket '/echo' => sub {
    my $self = shift;

    app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    $self->on(message => sub {
        my ($self, $msg) = @_;

        my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');

        for (keys %$clients) {
            $clients->{$_}->send({json => {
                hms  => $dt->hms,
                text => $msg,
            }});
        }
    });

    $self->on(finish => sub {
        app->log->debug('Client disconnected');
        delete $clients->{$id};
    });
};

app->start;

__DATA__
@@ index.html.ep
<head>
 <script src="myscripts.js"></script>
</head>

<html>
  <head>
    <title>WebSocket Client</title>
    <script
      type="text/javascript"
      src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"
    ></script>
    <script type="text/javascript" src="myscripts.js"></script>
    <style type="text/css">
      textarea {
          width: 40em;
          height:10em;
      }
    </style>
  </head>
<body>

<h1>Piano Trainer</h1>

<p><input type="text" id="msg" /></p>
<textarea id="log" readonly></textarea>

</body>
</html>


@@myscripts.js
$(function () {
  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };

  var ws = new WebSocket('ws://localhost:3000/echo');
  ws.onopen = function () {
    log('Connection opened');
  };

  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log('[' + res.hms + '] ' + res.text);
  };

$('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#msg').val());
        $('#msg').val('');
    }
  });
});
