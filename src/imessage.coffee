{User, Robot, Adapter, Message, TextMessage, Response} = require('hubot')
AppleScript = require('applescript')
path = require('path')

Redis = require('redis')
Pubsub = Redis.createClient()
Pubsub.subscribe('hubot:incoming-imessage')

class iMessageAdapter extends Adapter
  constructor: (robot) ->
    @robot = robot

  send: (envelope, strings...) ->
    user = envelope.user.id
    if user in @allowedUsers
      script = path.resolve(__dirname, 'Send iMessage.applescript')
      for message in strings
        AppleScript.execFile script,
          [user, message],
          (err, rtn) ->
    else
      @robot.logger.info 'Refusing to send message to unauthorized iMessage user ' + user

  reply: (envelope, strings...) ->
    @send envelope, strings...

  run: ->
    @allowedUsers = process.env.HUBOT_IMESSAGE_HANDLES.split(',')
    Pubsub.on 'message', (channel, dataString) =>
      data = JSON.parse(dataString)
      if data.userId in @allowedUsers
        user = @robot.brain.userForId(data.userId)
        user.name = data.name
        user.room = 'iMessage'

        # Upstream, they auto add the hubot name. I think it's better to explicitly
        #   have to type it to prevent weird collisions in normal conversations
        # msg = "#{@robot.name} #{data.message}"
        
        # needs robot name in front of the message to trigger a response
        msg = "#{data.message}" 
        @receive new TextMessage(user, msg)
      else
        @robot.logger.info 'Ignoring message from unauthorized iMessage user ' + data.userId
    @emit 'connected'

exports.use = (robot) ->
  new iMessageAdapter robot
