require 'spec_helper'

def only_error_message_should_include(partial_message)
  error_messages_should_include([partial_message])
  @validator.errors.full_messages.count.should == 1
end

def error_messages_should_include(array_of_regexes)
  @validator.should_not be_valid
  array_of_regexes.each do |partial_message|
    @validator.errors.full_messages.to_s.should match partial_message
  end
end

describe Diaspora::Federated::Validator::Private do 
  before do
    #this sucks
    salmon = stub(:verified_for_key? => true)
    @validator = Diaspora::Federated::Validator::Private.new(salmon, bob, alice.person)
    @object = Factory.build(:status_message, :author => alice.person)
    @validator.stub(:object).and_return(@object)
  end

  describe '#process!' do
    it 'does not save the object' do
      object = @validator.process!
      object.should_not be_persisted
    end 

    it 'returns nil if salmon signature does not check out' do
      @validator.stub(:valid_signature_on_envelope?).and_return false
      @validator.process!.should be_nil
    end

    it 'returns the object if the validator is valid' do
      @validator.process!.should == @object
    end

    it 'raises an error if the validations fail #temporary' do
      @validator.stub(:valid? => false)
      @validator.errors.add(:sender, "an example showing any error raises")
      expect{
        @validator.process!
      }.to raise_error
    end

  end

  context 'validations' do
    it 'starts as a valid instance' do
      @validator.should be_valid
    end


    describe '#model_is_valid?' do
      it 'adds an error the associated model is not valid' do
        #setup: the model parsed is not valid on its own accord
        @validator.object.stub(:valid?).and_return false
        only_error_message_should_include /Object/
      end
    end

    describe '#xml_author_matches_a_known_party' do
      it 'adds an error message if the object is not the same as the known party' do
        #setup: the known party is not the author of the parsed post
        @validator.stub(:expected_object_authority => "dog@bountyhunter.com")
        only_error_message_should_include /does not have write access/
      end
    end

    describe '#contact_required' do
      it 'adds error if object is not a request, and there is no a contact' do
        #setup: the sender is someone who is not a contact
        @validator.sender = Factory(:person) #set sender as unknown to bob
        error_messages_should_include([/Contact required/, /write access/])
      end
    end

    describe '#relayable_object_had_parent' do
      it 'adds an error if the object is relayable and has no parent' do
        #setup: the object is a relayable and has no parent, also it is valid?#why
        dh = @validator.object.diaspora_handle
        @validator.stub(:known_party).and_return(dh)
        @validator.object.stub(:respond_to? => true, :parent => nil, :valid? => true, :diaspora_handle => dh)

        only_error_message_should_include /Relayable Object has no known parent/
      end
    end
  end
end