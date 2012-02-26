module FederationIntegrationHelper
  def receive(post, opts)
    sender = opts.fetch(:from)
    receiver = opts.fetch(:by)
    salmon_xml = sender.salmon(post).xml_for(receiver.person)
    zord = Postzord::Receiver::Private.new(receiver, :salmon_xml => salmon_xml)
    zord.perform!
  end

  def temporary_user(&block)
    user = Factory(:user)
    block_return_value = yield user
    user.delete
    block_return_value
  end

  def temporary_post(user, &block)
    temp_post = user.post(:status_message, :text => 'hi')
    block_return_value = yield temp_post
    temp_post.delete
    block_return_value
  end

  def expect_error(partial_message, &block)
    begin 
      yield
    rescue => e
    ensure
      e.should be_present
      e.message.should match partial_message
    end
  end

  def bogus_retraction(&block)
    ret = Retraction.new
    yield ret
    ret
  end

  def user_should_not_see_guid(user, guid)
   user.reload.visible_shareables(Post).where(:guid => guid).should be_blank
  end
  
  #returns the message
  #should this be persisted? This actually fails a validation, as it is trying to save over the guid... :()
  def legit_post_from_user1_to_user2(user1, user2)
    original_message = user1.build_post(:status_message, :text => 'store this!', :to => user1.aspects.find_by_name("generic").id)

    receive(original_message, :from => user1, :by => user2)
    original_message
  end
end