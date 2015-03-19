from ws4py.client.threadedclient import WebSocketClient
from threading import Thread
from json import dumps, loads
import time

class Receiver(WebSocketClient):
  def opened(self):
    self.send(dumps({'action': 'add_peer'}))

  def received_message(self, data):
    print 'receiver received: %s' %(data)

class Initiator(WebSocketClient):
  def __init__(self, url):
    super(Initiator, self).__init__(url)
    self.remote_peer = None

  def opened(self):
    self.send(dumps({'action': 'add_peer'}))

  def received_message(self, message):
    print 'initiator received: %s' %(message)

    if not self.remote_peer:
      resp = loads(message.data)
      if resp.get('info') == 'peer.list':
        try:
          self.remote_peer = resp.get('data')[0]
        except IndexError:
          pass

if __name__ == '__main__':
  try:
    url = 'ws://localhost/api/v1/websocket'

    receiver = Receiver(url)
    receiver.connect()

    initiator = Initiator(url)
    initiator.connect()

    Thread(target=receiver.run_forever).start()
    Thread(target=initiator.run_forever).start()

    running = True
    while running:
      time.sleep(3)

      if initiator.remote_peer:
        initiator.send(dumps({
          'action': 'signal_peer',
          'peer_id': initiator.remote_peer,
          'data': 'test signalling'
        }))
      else:
        initiator.send(dumps({'action': 'list_peers'}))
  except KeyboardInterrupt:
    running = False
    receiver.close()
    initiator.close()
