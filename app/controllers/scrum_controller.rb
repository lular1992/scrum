class ScrumController < ApplicationController

  menu_item :scrum

  before_filter :find_issue, :only => [:change_story_points, :change_pending_effort,
                                       :change_assigned_to, :create_time_entry]
  before_filter :find_sprint, :only => [:new_pbi, :create_pbi]
  before_filter :find_pbi, :only => [:new_task, :create_task]
  before_filter :authorize, :except => [:new_pbi, :create_pbi, :new_task, :create_task]
  before_filter :authorize_add_issues, :only => [:new_pbi, :create_pbi, :new_task, :create_task]

  helper :scrum
  helper :timelog
  helper :custom_fields
  helper :projects

  def change_story_points
    begin
      @issue.story_points = params[:value]
      status = 200
    rescue
      status = 503
    end
    render :nothing => true, :status => status
  end

  def change_pending_effort
    @issue.pending_effort = params[:value]
    render :nothing => true, :status => 200
  end

  def change_assigned_to
    @issue.init_journal(User.current)
    @issue.assigned_to = params[:value].blank? ? nil : User.find(params[:value].to_i)
    @issue.save!
    render_task(@project, @issue, params)
  end

  def create_time_entry
    time_entry = TimeEntry.new(params[:time_entry])
    time_entry.project_id = @project.id
    time_entry.issue_id = @issue.id
    time_entry.user_id = params[:time_entry][:user_id]
    call_hook(:controller_timelog_edit_before_save, {:params => params, :time_entry => time_entry})
    time_entry.save!
    render_task(@project, @issue, params)
  end

  def new_pbi
    @pbi = Issue.new
    @pbi.project = @project
    @pbi.tracker = @project.trackers.find(params[:tracker_id])
    @pbi.author = User.current
    @pbi.sprint = @sprint
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create_pbi
    begin
      @continue = !(params[:create_and_continue].nil?)
      @pbi = Issue.new
      @pbi.project = @project
      @pbi.author = User.current
      @pbi.sprint = @sprint
      @pbi.tracker_id = params[:issue][:tracker_id]
      @pbi.subject = params[:issue][:subject]
      @pbi.priority_id = params[:issue][:priority_id]
      @pbi.estimated_hours = params[:issue][:estimated_hours]
      @pbi.description = params[:issue][:description]
      @pbi.category_id = params[:issue][:category_id] if @pbi.safe_attribute?(:category_id)
      @pbi.fixed_version_id = params[:issue][:fixed_version_id] if @pbi.safe_attribute?(:fixed_version_id)
      @pbi.start_date = params[:issue][:start_date] if @pbi.safe_attribute?(:start_date)
      @pbi.due_date = params[:issue][:due_date] if @pbi.safe_attribute?(:due_date)
      @pbi.custom_field_values = params[:issue][:custom_field_values] unless params[:issue][:custom_field_values].nil?
      @pbi.save!
      @pbi.story_points = params[:issue][:story_points]
    rescue Exception => @exception
      log.error("Exception: #{@exception.inspect}")
    end
    respond_to do |format|
      format.js
    end
  end

  def new_task
    @task = Issue.new
    @task.project = @project
    @task.tracker = Tracker.find(params[:tracker_id])
    @task.parent = @pbi
    @task.author = User.current
    @task.sprint = @sprint
    if Scrum::Setting.inherit_pbi_attributes
      @task.inherit_from_issue(@pbi)
    end
    respond_to do |format|
      format.html
      format.js
    end
  rescue Exception => e
    log.error("Exception: #{e.inspect}")
    render_404
  end

  def create_task
    begin
      @continue = !(params[:create_and_continue].nil?)
      @task = Issue.new
      @task.project = @project
      @task.parent_issue_id = @pbi.id
      @task.author = User.current
      @task.sprint = @sprint
      @task.tracker_id = params[:issue][:tracker_id]
      @task.subject = params[:issue][:subject]
      @task.priority_id = params[:issue][:priority_id]
      @task.estimated_hours = params[:issue][:estimated_hours]
      @task.description = params[:issue][:description]
      @task.category_id = params[:issue][:category_id] if @task.safe_attribute?(:category_id)
      @task.fixed_version_id = params[:issue][:fixed_version_id] if @task.safe_attribute?(:fixed_version_id)
      @task.start_date = params[:issue][:start_date] if @task.safe_attribute?(:start_date)
      @task.due_date = params[:issue][:due_date] if @task.safe_attribute?(:due_date)
      @task.custom_field_values = params[:issue][:custom_field_values] unless params[:issue][:custom_field_values].nil?
      @task.save!
      @task.pending_effort = params[:issue][:pending_effort]
    rescue Exception => @exception
    end
    respond_to do |format|
      format.js
    end
  end

private

  def render_task(project, task, params)
    render :partial => "post_its/sprint_board/task",
           :status => 200,
           :locals => {:project => project,
                       :task => task,
                       :pbi_status_id => params[:pbi_status_id],
                       :other_pbi_status_ids => params[:other_pbi_status_ids].split(","),
                       :task_id => params[:task_id]}
  end

  def find_sprint
    @sprint = Sprint.find(params[:sprint_id])
    @project = @sprint.project
  rescue
    log.error("Sprint #{params[:sprint_id]} not found")
    render_404
  end

  def find_pbi
    @pbi = Issue.find(params[:pbi_id])
    @sprint = @pbi.sprint
    @project = @sprint.project
  rescue
    log.error("PBI #{params[:pbi_id]} not found")
    render_404
  end

  def authorize_add_issues
    if User.current.allowed_to?(:add_issues, @project)
      return true
    else
      render_403
      return false
    end
  end

end
