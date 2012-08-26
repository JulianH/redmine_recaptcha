module IssuesControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :create, :recaptcha_verification
      alias_method_chain :update, :recaptcha_verification
    end
  end
  
  module InstanceMethods
    def create_with_recaptcha_verification
      call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
      @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
      if (User.current.logged? || verify_recaptcha( :private_key => Setting.plugin_redmine_recaptcha['recaptcha_private_key'], :model => @issue, :message => "There was an error with the recaptcha code below. Please re-enter the code and click submit." )) && @issue.save
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        respond_to do |format|
          format.html {
            render_attachment_warning_if_needed(@issue)
            flash[:notice] = l(:notice_issue_successful_create, :id => "<a href='#{issue_path(@issue)}'>##{@issue.id}</a>")
            redirect_to(params[:continue] ?  { :action => 'new', :project_id => @issue.project, :issue => {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?} } :
            { :action => 'show', :id => @issue })
          }
          format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
        end
        return
      else
        respond_to do |format|
          format.html { render :action => 'new' }
          format.api  { render_validation_errors(@issue) }
        end
      end
    end
    
    def update_with_recaptcha_verification
      return unless update_issue_from_params
      if (User.current.logged? || verify_recaptcha( :private_key => Setting.plugin_redmine_recaptcha['recaptcha_private_key'], :model => @issue, :message => "There was an error with the recaptcha code below. Please re-enter the code and click submit." ))
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@issue) }
        end
        return false
      end
      @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
      saved = false
      begin
        saved = @issue.save_issue_with_child_records(params, @time_entry)
      rescue ActiveRecord::StaleObjectError
        @conflict = true
        if params[:last_journal_id]
          if params[:last_journal_id].present?
            last_journal_id = params[:last_journal_id].to_i
            @conflict_journals = @issue.journals.all(:conditions => ["#{Journal.table_name}.id > ?", last_journal_id])
          else
            @conflict_journals = @issue.journals.all
          end
        end
      end

      if saved
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

        respond_to do |format|
          format.html { redirect_back_or_default({:action => 'show', :id => @issue}) }
          format.api  { head :ok }
        end
      else
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@issue) }
        end
      end
    end

  end
end
