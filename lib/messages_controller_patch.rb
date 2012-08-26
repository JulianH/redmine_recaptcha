module MessagesControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :new, :recaptcha_verification
      alias_method_chain :reply, :recaptcha_verification
    end
  end
  
  module InstanceMethods    
    def new_with_recaptcha_verification
      @message = Message.new
      @message.author = User.current
      @message.board = @board
      @message.safe_attributes = params[:message]
      if request.post?
        @message.save_attachments(params[:attachments])
        if (User.current.logged? || verify_recaptcha( :private_key => Setting.plugin_redmine_recaptcha['recaptcha_private_key'], :model => @message, :message => "There was an error with the recaptcha code below. Please re-enter the code and click submit." )) && @message.save
          call_hook(:controller_messages_new_after_save, { :params => params, :message => @message})
          render_attachment_warning_if_needed(@message)
          redirect_to board_message_path(@board, @message)
        end
      end
    end
    
    def reply_with_recaptcha_verification
      if !(User.current.logged? || verify_recaptcha( :private_key => Setting.plugin_redmine_recaptcha['recaptcha_private_key'], :model => @topic, :message => "There was an error with the recaptcha code below. Please re-enter the code and click submit." ))
        @reply = Message.new(params[:reply])
        @reply.author = User.current
        @reply.board = @board
        render :action => 'reply', :id => @topic, :reply => @reply and return
      end
      @reply = Message.new(params[:reply])
      @reply.author = User.current
      @reply.board = @board
      @topic.children << @reply
      if !@reply.new_record?
        call_hook(:controller_messages_reply_after_save, { :params => params, :message => @reply})
        attachments = Attachment.attach_files(@reply, params[:attachments])
        render_attachment_warning_if_needed(@reply)
      end
      redirect_to :action => 'show', :id => @topic, :r => @reply
    end
  end
end