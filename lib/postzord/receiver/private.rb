  #   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.
require File.join(Rails.root, 'lib/webfinger')
require File.join(Rails.root, 'lib/diaspora/federated/parser')
require File.join(Rails.root, 'lib/diaspora/federated/validator/private')



#there are three phases of this object
# 1. accept xml
# 2. validate and emit the object
# 3. recieve the object by the user
# 4. post recieve callbacks
# 
# currently, there are two gross ways into this object, one which takes encrypted xml,
# and another which takes an object directly

class Postzord::Receiver::PrivateLocal

end


#note, two code paths to extract here :/
# decent federation case 1. call with salmon_xml from federation request, and call receive
# bad internal case: 2. with non salmonified xml (this is because requests and retractions are not persisted, but still unique to individuals)
# bad internal case: 3: with an object instance directly, which is for persisted objects, but same reasoning as above.
class Postzord::Receiver::Private < Postzord::Receiver
  attr_accessor :object, :user, :sender, :salmon, :salmon_xml

  def initialize(user, opts={})
    self.user = user
    self.salmon_xml = opts[:salmon_xml]
    self.sender = opts[:person] || Webfinger.new(self.salmon.author_id).fetch
    @actor = @sender
    self.object = opts[:object]
  end


  #called from xml provided by the outside world
  def receive!
    validator = Diaspora::Federated::Validator::Private.new(self.salmon, @user, @sender)
    if self.object = validator.process! #this should raise
      refreshed_object = accept_object_for_user #this SHOULD emit an instance of the object if it already exists, or itself
      post_receive_hooks(refreshed_object)
    else
      FEDERATION_LOGGER.info("failed to receive object: #{validator.errors.inspect}")
      false
    end
  end

  #called from local code paths only, so we dont need to do all the validation checks
  def parse_and_receive(xml)
    self.object = create_object_from_local(xml)
    receive_object
 end

  #this is a method to get the tests to pass
  # it is used where we manaully pass an already parsed object into be received
  def receive_object
    obj = accept_object_for_user
    post_receive_hooks(obj)
  end


  # @return [Object]
  def accept_object_for_user
    obj = object.receive(@user, object.author)
    FEDERATION_LOGGER.info("user:#{@user.id} successfully received private post from person#{@sender.guid} #{@object.inspect}")
    obj
  end

  def post_receive_hooks(obj)
    notify_receiver(obj)
  end

  protected

  def create_object_from_local(xml)
     Diaspora::Federated::Parser.new(xml, @sender).parse!
  end

  def salmon
    @salmon ||= Salmon::EncryptedSlap.from_xml(@salmon_xml, @user)
  end

  def notify_receiver(obj)
    if obj.respond_to?(:notification_type)
      Notification.notify(@user, obj, @object.author) 
    else
      FEDERATION_LOGGER.info("WARNING: object #{obj.inspect}: did not respond_t0 notification_type")
    end
  end
end