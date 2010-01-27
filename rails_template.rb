require 'open-uri'
 
def download(from, to = from.split("/").last)
  #run "curl -s -L #{from} > #{to}"
  file to, open(from).read
rescue
  puts "Can't get #{from} - Internet down?"
  exit!
end

def commit_state(comment)
  git :add => "."
  git :commit => "-am '#{comment}'"
end

current_app_name = File.basename(File.expand_path(root))

# Delete unnecessary files
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"

# Set up git repository
git :init
  
# gems
gem 'authlogic', :source => 'http://www.gemcutter.org'
gem 'declarative_authorization', :source => 'http://www.gemcutter.org'
gem 'will_paginate', :source => 'http://www.gemcutter.org'
gem 'stringex', :source => 'http://www.gemcutter.org'
gem 'paperclip', :source => 'http://www.gemcutter.org'
gem 'less', :source => 'http://www.gemcutter.org'
gem 'aasm', :source => 'http://www.gemcutter.org'
gem 'whenever', :lib => false, :source => 'http://www.gemcutter.org'

rake("gems:install", :sudo => true)

plugin 'more', :git => "git://github.com/cloudhead/more.git"
plugin 'enum_field', :git => "git://github.com/jamesgolick/enum_field.git"
plugin 'jrails', :git => "git://github.com/aaronchi/jrails.git"

# Set up gitignore and commit base state
file '.gitignore', <<-END
config/database.yml
log/*.log
tmp/**/*
.DS\_Store
.DS_Store
/log/*.pid
public/system/*
tmp/sent_mails/*
public/stylesheets/*
END

commit_state "Base application with plugins and gems"

# some files for app

file 'app/views/layouts/_flashes.html.erb', <<-END
<div id="flash">
  <% flash.each do |key, value| -%>
    <div id="flash_<%= key %>"><%=h value %></div>
  <% end -%>
</div>
END

run "mkdir app/views/shared"
file 'app/views/shared/_navigation.html.erb', <<-END
<ul id="navlist">
	<li><%= link_to "Home", root_path %></li>
	<li>Test</li>
</ul>
END

file 'app/views/layouts/application.html.erb', <<-END
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
    <title><%= @page_title || controller.action_name %></title>
    
    
    <script src="http://www.google.com/jsapi"></script>
  	<script language = "javascript" type="text/javascript"> 
  		google.load("jquery", "1.3.2");
  	</script>

  	<script src="/javascripts/jrails.js" type="text/javascript"></script>

    <%= yield :javascripts %>
    
    <%= stylesheet_link_tag 'blueprint/screen.css', :media => "screen, projection" %>
    <%= stylesheet_link_tag 'blueprint/print.css', :media => "print" %>
    <!--[if lt IE 8]>
      <%= stylesheet_link_tag 'blueprint/ie.css', :media => "screen, projection" %>
    <![endif]-->
    
    <%= stylesheet_link_tag 'app' %>
    <%= yield :stylesheets %>
  </head>
  <body>
    <div class="container">
  	<div id="navigation" class="span-24 last">
  		<%= render :partial => 'shared/navigation'%>
  	</div>
    <%= render :partial => 'layouts/flashes' -%>
    <%= yield %>
    </div>
  </body>
</html>
END


file 'app/controllers/application_controller.rb', <<-END
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  helper :all # include all helpers, all the time
  
  # make methods available to views
  helper_method :logged_in?, :current_user_session, :current_user
  
  # See ActionController::RequestForgeryProtection for details
  protect_from_forgery
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  filter_parameter_logging :password, :confirm_password, :password_confirmation, :creditcard
  
  before_filter { |c| Authorization.current_user = c.current_user}
  before_filter :set_time_zone
  
  def logged_in?
    !current_user_session.nil?
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def set_time_zone
    Time.zone = @current_user.time_zone if @current_user
  end  
  
private
  def require_user
    unless current_user
      store_location
      flash[:notice] = "You must be logged in to access this page"
      redirect_to new_user_session_url
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = "You must be logged out to access this page"
      redirect_to account_url
      return false
    end
  end
  
  def store_location
    session[:return_to] = request.request_uri
  end
  
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
end
END

file 'app/helpers/application_helper.rb', <<-END
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  # Block method that creates an area of the view that
  # is only rendered if the request is coming from an
  # anonymous user.
  def anonymous_only(&block)
    if !logged_in?
      block.call
    end
  end
  
  # Block method that creates an area of the view that
  # only renders if the request is coming from an
  # authenticated user.
  def authenticated_only(&block)
    if logged_in?
      block.call
    end
  end
end
END

# initializers
initializer 'requires.rb', <<-END
Dir[File.join(RAILS_ROOT, 'lib', '*.rb')].each do |f|
  require f
end
END

initializer 'mail.rb', <<-END
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address => "111.111.111.111",
  :port => 25,
  :domain => "example.com",
  :authentication => :login,
  :user_name => "mikeg1@example.com",
  :password => "password"  
}
END

initializer 'date_time_formats.rb', <<-END
ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
  :us => '%m/%d/%y',
  :us_with_time => '%m/%d/%y, %l:%M %p',
  :short_with_time => '%e %B %Y, %l:%M %p',
  :short_day => '%e %B %Y',
  :long_day => '%A, %e %B %Y',
  :short_time => '%l:%M %p'
)

Date::DATE_FORMATS[:human] = "%B %e, %Y"
END

commit_state "application files and initializers"

#wheneverize
run "wheneverize ."

commit_state "wheneverize"

# deployment
capify!

file 'config/deploy.rb', <<-END
set :application, "#{current_app_name}"
set :repository,  "git@github:#{current_app_name}.git"
set :user, "deploy"
set :deploy_via, :remote_cache
set :scm, :git

# Customise the deployment

set :keep_releases, 3
after "deploy:update", "deploy:cleanup"
after "deploy:symlink", "deploy:update_crontab"

# directories to preserve between deployments
# set :asset_directories, ['public/system/logos', 'public/system/uploads']

# re-linking for config files on public repos  
# namespace :deploy do
#   desc "Update the crontab file"
#   task :update_crontab, :roles => :db do
#     run "cd \#{release_path} && whenever --update-crontab \#{application}"
#   end
#   desc "Re-link config files"
#   task :link_config, :roles => :app do
#     run "ln -nsf \#{shared_path}/config/database.yml \#{current_path}/config/database.yml"
#   end
# end
    
END

file 'config/deploy/production.rb', <<-END
set :host, "111.111.111.111"
set :branch, "master"
END

file 'config/deploy/staging.rb', <<-END
set :host, "111.111.111.111"
set :branch, "staging"
END

commit_state "deployment files"

# database
file 'config/database.yml', <<-END
development:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{current_app_name.gsub(/[-]/, '_')}_development
  pool: 5
  username: 
  password: 
  socket: /tmp/mysql.sock

test:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{current_app_name.gsub(/[-]/, '_')}_test
  pool: 5
  username: 
  password: 
  socket: /tmp/mysql.sock


production:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{current_app_name.gsub(/[-]/, '_')}_production
  pool: 5
  username: 
  password: 
  socket: /tmp/mysql.sock

staging:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{current_app_name.gsub(/[-]/, '_')}_production
  pool: 5
  username: 
  password: 
  socket: /tmp/mysql.sock
END

commit_state "configuration files"


# authlogic setup
file 'app/controllers/password_resets_controller.rb', <<-END
class PasswordResetsController < ApplicationController
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  before_filter :require_no_user
  
  def new
    @page_title = "Forgot Password?"
  end
  
  def create
    @user = User.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = "Instructions to reset your password have been emailed to you. " +
        "Please check your email."
      redirect_to root_url
    else
      flash[:notice] = "No user was found with that email address"
      render :action => :new
    end
  end
  
  def edit
    @page_title = "Select a New Password"
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      flash[:notice] = "Password successfully updated"
      redirect_to account_url
    else
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = User.find_using_perishable_token(params[:id])
      unless @user
        flash[:notice] = "We're sorry, but we could not locate your account." +
          "If you are having issues try copying and pasting the URL " +
          "from your email into your browser or restarting the " +
          "reset password process."
        redirect_to root_url
      end
    end
end
END

file 'app/controllers/user_sessions_controller.rb', <<-END
class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  
  def new
    @page_title = "Login"
    @user_session = UserSession.new
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end
end
END

file 'app/controllers/users_controller.rb', <<-END
class UsersController < ApplicationController

  #declarative_authorization
  #filter_resource_access
  
  def index
    @users = User.all
    @page_title = "All Users"
  end
  
  def new
    @user = User.new
    @page_title = "Create Account"
  end
  
  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end
  
  def show
    @user = current_user
    @page_title = "\#{@user.login} details"
  end

  def edit
    @user = User.find(params[:id])
    @page_title = "Edit \#{@user.login}"
  end
  
  def update
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end

  def destroy
    @user.destroy
    flash[:notice] = 'User was deleted.'
    redirect_to(users_url)  
  end
  
end
END

file 'app/models/notifier.rb', <<-END
class Notifier < ActionMailer::Base
  default_url_options[:host] = "larkfarm.com"
  
  def password_reset_instructions(user)
    subject       "Password Reset Instructions"
    from          "Administrator <noreply@example.com>"
    recipients    user.email
    sent_on       Time.now
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)
  end
end
END

file 'app/models/user.rb', <<-END
class User < ActiveRecord::Base
  acts_as_authentic
  
  has_and_belongs_to_many :roles
  attr_accessible :login, :password, :password_confirmation, :email, :first_name, :last_name,:role_ids, :time_zone
  
  #for declarative authorization
  def role_symbols
    roles.map do |role|
      role.name.underscore.to_sym
    end
  end
  
  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.deliver_password_reset_instructions(self)
  end

end
END

file 'app/models/user_session.rb', <<-END
class UserSession < Authlogic::Session::Base
end
END

file 'app/views/notifier/password_reset_instructions.erb', <<-END
A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request just click the link below:

<%= @edit_password_reset_url %>

If the above URL does not work try copying and pasting it into your browser. If you continue to have problem please feel free to contact us.
END

file 'app/views/password_resets/edit.html.erb', <<-END
<h1>Change My Password</h1>

<% form_for @user, :url => password_reset_path, :method => :put do |f| %>
  <%= f.error_messages %>
  <%= f.label :password %><br />
  <%= f.password_field :password %><br />
  <br />
  <%= f.label :password_confirmation %><br />
  <%= f.password_field :password_confirmation %><br />
  <br />
  <%= f.submit "Update my password and log me in" %>
<% end %>
END

file 'app/views/password_resets/new.html.erb', <<-END
<h1>Forgot Password</h1>

Fill out the form below and instructions to reset your password will be emailed to you:<br />
<br />

<% form_tag password_resets_path do %>
  <label>Email:</label><br />
  <%= text_field_tag "email" %><br />
  <br />
  <%= submit_tag "Reset my password" %>
<% end %>
END

file 'app/views/user_sessions/new.html.erb', <<-END
<h1>Login</h1>

<% form_for @user_session, :url => user_session_path do |f| %>
  <%= f.error_messages %>
  <%= f.label :login %><br />
  <%= f.text_field :login %><br />
  <br />
  <%= f.label :password %><br />
  <%= f.password_field :password %><br />
  <br />
  <%= f.check_box :remember_me %><%= f.label :remember_me %><br />
  <br />
  <%= f.submit "Login" %>
<% end %>
END

file 'app/views/users/index.html.erb', <<-END
<h1>Listing users</h1>

<table>
  <tr>
    <th>Login</th>
    <th colspan="3"></th>
  </tr>

<% @users.each do |user| %>
  <tr>
    <td><%=h user.login %></td>
    <td><%= link_to 'Show', user %></td>
    <td><%= link_to 'Edit', edit_user_path(user) %></td>
    <td><%= link_to 'Destroy', user, :confirm => 'Are you sure?', :method => :delete %></td>
  </tr>
<% end %>
</table>

<br />

<%= link_to 'New user', new_user_path %>
END

file 'app/views/users/_form.html.erb', <<-END
<%= form.label :first_name %><br />
<%= form.text_field :first_name %><br />
<br />
<%= form.label :last_name %><br />
<%= form.text_field :last_name %><br />
<br />
<%= form.label :login %><br />
<%= form.text_field :login %><br />
<br />
<%= form.label :password, form.object.new_record? ? nil : "Change password" %><br />
<%= form.password_field :password %><br />
<br />
<%= form.label :password_confirmation %><br />
<%= form.password_field :password_confirmation %><br />
<br />
<%= form.label :email %><br />
<%= form.text_field :email %><br />
<br />
<%= form.label :time_zone %><br />
<%= form.time_zone_select :time_zone, ActiveSupport::TimeZone.us_zones %><br />
<br />
END

file 'app/views/users/edit.html.erb', <<-END
<h1>Edit My Account</h1>

<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => "form", :object => f %>
  <%= f.submit "Update" %>
<% end %>

<br /><%= link_to "My Profile", account_path %>
END

file 'app/views/users/new.html.erb', <<-END
<h1>Register</h1>

<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => "form", :object => f %>
  <%= f.submit "Register" %>
<% end %>
END

file 'app/views/users/show.html.erb', <<-END
<p>
  <b>Login:</b>
  <%=h @user.login %>
</p>

<p>
  <b>Email:</b>
  <%=h @user.email %>
</p>

<p>
  <b>Login count:</b>
  <%=h @user.login_count %>
</p>

<p>
  <b>Last request at:</b>
  <%=h @user.last_request_at %>
</p>

<p>
  <b>Last login at:</b>
  <%=h @user.last_login_at %>
</p>

<p>
  <b>Current login at:</b>
  <%=h @user.current_login_at %>
</p>

<p>
  <b>Last login ip:</b>
  <%=h @user.last_login_ip %>
</p>

<p>
  <b>Current login ip:</b>
  <%=h @user.current_login_ip %>
</p>


<%= link_to 'Edit', edit_account_path %>
END

file 'db/migrate/01_create_users.rb', <<-END
class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.timestamps
      t.string :login, :null => false
      t.string :crypted_password, :null => false
      t.string :password_salt, :null => false
      t.string :persistence_token, :null => false
      t.integer :login_count, :default => 0, :null => false
      t.datetime :last_request_at
      t.datetime :last_login_at
      t.datetime :current_login_at
      t.string :last_login_ip
      t.string :current_login_ip
      t.string :first_name
      t.string :last_name
      t.string :perishable_token, :default => "", :null => false
      t.string :email, :default => "", :null => false
      t.string :time_zone
    end
    
    add_index :users, :login
    add_index :users, :persistence_token
    add_index :users, :last_request_at
    add_index :users, :perishable_token
    add_index :users, :email
  end
  
  #add admin user

  def self.down
    drop_table :users
  end
end
END

file 'db/migrate/02_create_sessions.rb', <<-END
class CreateSessions < ActiveRecord::Migration
  def self.up
    create_table :sessions do |t|
      t.string :session_id, :null => false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at
  end

  def self.down
    drop_table :sessions
  end
end
END

file 'db/migrate/03_create_roles.rb', <<-END
class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.string :name
      t.timestamps
    end
    
    create_table :roles_users, :id => false, :force => true do |t|
      t.integer :role_id
      t.integer :user_id
    end
  end
  
  def self.down
    drop_table :role_users
    drop_table :roles
  end
end
END

#dclarative authorization
file 'app/controllers/roles_controller.rb', <<-END
class RolesController < ApplicationController
  # GET /roles
  def index
    @roles = Role.all

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /roles/1
  # GET /roles/1.xm
  def show
    @role = Role.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  # GET /roles/new
  def new
    @role = Role.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /roles/1/edit
  def edit
    @role = Role.find(params[:id])
  end

  # POST /roles
  def create
    @role = Role.new(params[:role])

    respond_to do |format|
      if @role.save
        flash[:notice] = 'Role was successfully created.'
        format.html { redirect_to(@role) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /roles/1
  def update
    @role = Role.find(params[:id])

    respond_to do |format|
      if @role.update_attributes(params[:role])
        flash[:notice] = 'Role was successfully updated.'
        format.html { redirect_to(@role) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  # DELETE /roles/1
  def destroy
    @role = Role.find(params[:id])
    @role.destroy

    respond_to do |format|
      format.html { redirect_to(roles_url) }
    end
  end
end
END

file 'app/models/role.rb', <<-END
class Role < ActiveRecord::Base
  has_and_belongs_to_many :users
end  
END


file 'config/authorization_rules.rb', <<-END
authorization do
  role :guest do
    #has_permission_on :controller, :to => [:index, :show ]
  end

  role :admin do
    has_permission_on :users, :to => [:index, :show, :new, :create, :edit, :update, :destroy]
  end
end
END

file 'db/seeds.rb', <<-END
  User.create(:login => 'admin', :password=> 'password1', :password_confirmation => 'password1', :email=> "admin@#{current_app_name}.com")
  Role.create(:name => 'admin')
  Role.create(:name => 'user')
  User.first.roles << Role.find_by_name("admin")
END

commit_state "basic Authlogic & Declarative Authorization setup"

# download Blueprint
inside ('app/stylesheets') do
  run "mkdir blueprint;"
  run 'curl -L  http://github.com/joshuaclayton/blueprint-css/raw/master/blueprint/ie.css > blueprint/ie.css'
  run 'curl -L  http://github.com/joshuaclayton/blueprint-css/raw/master/blueprint/screen.css > blueprint/screen.css'
  run 'curl -L  http://github.com/joshuaclayton/blueprint-css/raw/master/blueprint/print.css > blueprint/print.css'
end

file 'app/stylesheets/app.less', <<-END
@font-family: helvetica, arial, sans-serif;
body {
  font-family: @font-family;
  font-size: 16px;
}

/* navigation */

ul#navlist {
	float:right;
	margin:0;
	display:block;
}

ul#navlist li {
	background-color:#ccc;
	border-left:1px solid #FFFFFF;
	border-top:1px solid #FFFFFF;
	display:inline;
	float:left;
	font-weight:bold;
	list-style-type:none;
	margin-top: 15px;
	padding:5px 10px;
}

/* Forms */
input[type=text], input[type=password], select {
	font-size: 20px;
	padding: 3px;
}

input[type=submit] {
	font-size: 18px;
}
END

rake('more:parse')

commit_state "css"

# static pages
file 'app/controllers/pages_controller.rb', <<-END
class PagesController < ApplicationController
  
  def home
    @page_title = '#{current_app_name}'
  end
  
  def css_test
    @page_title = "CSS Test"
  end
  
end
END

file 'app/views/pages/home.html.erb', <<-END
<div id="top_menu">
  <% anonymous_only do %>
    <%= link_to "Register", new_account_path %>
    <%= link_to "Login", new_user_session_path %>
  <% end %>
  <% authenticated_only do %>
    <%= link_to "Logout", user_session_path, :method => :delete, :confirm => "Are you sure you want to logout?" %>
  <% end %>
</div>

<div id="main">
  <h1>Welcome to #{current_app_name}</h1>
  <p>Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p>
</div>

<div id="left_menu">
  <% anonymous_only do %>
    <%= link_to "Register", new_account_path %>
    <%= link_to "Login", new_user_session_path %>
  <% end %>
  <% authenticated_only do %>
  <% end %>
</div>
END

file 'app/views/pages/css_test.html.erb', <<-END
<!-- Sample Content to Plugin to Template -->
<h1>CSS Basic Elements</h1>

<p>The purpose of this HTML is to help determine what default settings are with CSS and to make sure that all possible HTML Elements are included in this HTML so as to not miss any possible Elements when designing a site.</p>

<hr />

<h1 id="headings">Headings</h1>

<h1>Heading 1</h1>
<h2>Heading 2</h2>
<h3>Heading 3</h3>
<h4>Heading 4</h4>
<h5>Heading 5</h5>
<h6>Heading 6</h6>

<small><a href="#wrapper">[top]</a></small>
<hr />


<h1 id="paragraph">Paragraph</h1>

<img style="width:250px;height:125px;float:right" src="images/css_gods_language.png" alt="CSS | God's Language" />
<p>Lorem ipsum dolor sit amet, <a href="#" title="test link">test link</a> adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. Donec faucibus. Nunc iaculis suscipit dui. Nam sit amet sem. Aliquam libero nisi, imperdiet at, tincidunt nec, gravida vehicula, nisl. Praesent mattis, massa quis luctus fermentum, turpis mi volutpat justo, eu volutpat enim diam eget metus. Maecenas ornare tortor. Donec sed tellus eget sapien fringilla nonummy. Mauris a ante. Suspendisse quam sem, consequat at, commodo vitae, feugiat in, nunc. Morbi imperdiet augue quis tellus.</p>

<p>Lorem ipsum dolor sit amet, <em>emphasis</em> consectetuer adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. Donec faucibus. Nunc iaculis suscipit dui. Nam sit amet sem. Aliquam libero nisi, imperdiet at, tincidunt nec, gravida vehicula, nisl. Praesent mattis, massa quis luctus fermentum, turpis mi volutpat justo, eu volutpat enim diam eget metus. Maecenas ornare tortor. Donec sed tellus eget sapien fringilla nonummy. Mauris a ante. Suspendisse quam sem, consequat at, commodo vitae, feugiat in, nunc. Morbi imperdiet augue quis tellus.</p>

<small><a href="#wrapper">[top]</a></small>
<hr />

<h1 id="list_types">List Types</h1>

<h3>Definition List</h3>
<dl>
	<dt>Definition List Title</dt>
	<dd>This is a definition list division.</dd>
</dl>

<h3>Ordered List</h3>
<ol>
	<li>List Item 1</li>
	<li>List Item 2</li>
	<li>List Item 3</li>
</ol>

<h3>Unordered List</h3>
<ul>
	<li>List Item 1</li>
	<li>List Item 2</li>
	<li>List Item 3</li>
</ul>

<small><a href="#wrapper">[top]</a></small>
<hr />

<h1 id="form_elements">Fieldsets, Legends, and Form Elements</h1>

<fieldset>
	<legend>Legend</legend>
	
	<p>Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. Donec faucibus. Nunc iaculis suscipit dui. Nam sit amet sem. Aliquam libero nisi, imperdiet at, tincidunt nec, gravida vehicula, nisl. Praesent mattis, massa quis luctus fermentum, turpis mi volutpat justo, eu volutpat enim diam eget metus.</p>
	
	<form>
		<h2>Form Element</h2>
		
		<p>Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. Donec faucibus. Nunc iaculis suscipit dui.</p>
		
		<p><label for="text_field">Text Field:</label><br />
		<input type="text" id="text_field" /></p>
		
		<p><label for="text_area">Text Area:</label><br />
		<textarea id="text_area"></textarea></p>
		
		<p><label for="select_element">Select Element:</label><br />
			<select name="select_element">
			<optgroup label="Option Group 1">
				<option value="1">Option 1</option>
				<option value="2">Option 2</option>
				<option value="3">Option 3</option>
			</optgroup>
			<optgroup label="Option Group 2">
				<option value="1">Option 1</option>
				<option value="2">Option 2</option>
				<option value="3">Option 3</option>
			</optgroup>
		</select></p>
		
		<p><label for="radio_buttons">Radio Buttons:</label><br />
			<input type="radio" class="radio" name="radio_button" value="radio_1" /> Radio 1<br/>
				<input type="radio" class="radio" name="radio_button" value="radio_2" /> Radio 2<br/>
				<input type="radio" class="radio" name="radio_button" value="radio_3" /> Radio 3<br/>
		</p>
		
		<p><label for="checkboxes">Checkboxes:</label><br />
			<input type="checkbox" class="checkbox" name="checkboxes" value="check_1" /> Radio 1<br/>
				<input type="checkbox" class="checkbox" name="checkboxes" value="check_2" /> Radio 2<br/>
				<input type="checkbox" class="checkbox" name="checkboxes" value="check_3" /> Radio 3<br/>
		</p>
		
		<p><label for="password">Password:</label><br />
			<input type="password" class="password" name="password" />
		</p>
		
		<p><label for="file">File Input:</label><br />
			<input type="file" class="file" name="file" />
		</p>
		
		
		<p><input class="button" type="reset" value="Clear" /> <input class="button" type="submit" value="Submit" />
		</p>
		

		
	</form>
	
</fieldset>

<small><a href="#wrapper">[top]</a></small>
<hr />

<h1 id="tables">Tables</h1>

<table cellspacing="0" cellpadding="0">
	<tr>
		<th>Table Header 1</th><th>Table Header 2</th><th>Table Header 3</th>
	</tr>
	<tr>
		<td>Division 1</td><td>Division 2</td><td>Division 3</td>
	</tr>
	<tr class="even">
		<td>Division 1</td><td>Division 2</td><td>Division 3</td>
	</tr>
	<tr>
		<td>Division 1</td><td>Division 2</td><td>Division 3</td>
	</tr>

</table>

<small><a href="#wrapper">[top]</a></small>
<hr />

<h1 id="misc">Misc Stuff - abbr, acronym, pre, code, sub, sup, etc.</h1>

<p>Lorem <sup>superscript</sup> dolor <sub>subscript</sub> amet, consectetuer adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. <cite>cite</cite>. Nunc iaculis suscipit dui. Nam sit amet sem. Aliquam libero nisi, imperdiet at, tincidunt nec, gravida vehicula, nisl. Praesent mattis, massa quis luctus fermentum, turpis mi volutpat justo, eu volutpat enim diam eget metus. Maecenas ornare tortor. Donec sed tellus eget sapien fringilla nonummy. <acronym title="National Basketball Association">NBA</acronym> Mauris a ante. Suspendisse quam sem, consequat at, commodo vitae, feugiat in, nunc. Morbi imperdiet augue quis tellus.  <abbr title="Avenue">AVE</abbr></p>

<pre><p>Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nullam dignissim convallis est. Quisque aliquam. Donec faucibus. Nunc iaculis suscipit dui. Nam sit amet sem. Aliquam libero nisi, imperdiet at, tincidunt nec, gravida vehicula, nisl. Praesent mattis, massa quis luctus fermentum, turpis mi volutpat justo, eu volutpat enim diam eget metus. Maecenas ornare tortor. Donec sed tellus eget sapien fringilla nonummy. <acronym title="National Basketball Association">NBA</acronym> Mauris a ante. Suspendisse quam sem, consequat at, commodo vitae, feugiat in, nunc. Morbi imperdiet augue quis tellus.  <abbr title="Avenue">AVE</abbr></p></pre>

<blockquote>
	"This stylesheet is going to help so freaking much." <br />-Blockquote
</blockquote>

<small><a href="#wrapper">[top]</a></small>
<!-- End of Sample Content -->
END


commit_state "static pages"

# simple default routing
file 'config/routes.rb', <<-END
ActionController::Routing::Routes.draw do |map|
  map.resource :account, :controller => "users"
  map.resources :password_resets
  map.resources :users
  map.resource :user_session
  map.login 'login', :controller => "user_sessions", :action => "new"
  map.logout 'logout', :controller => "user_sessions", :action => "destroy"
  map.register 'register', :controller => "users", :action => "new"
  map.root :controller => "pages", :action => "home"
  map.pages 'pages/:action', :controller => "pages"
end
END

commit_state "routing"

# Success!
puts "SUCCESS!"
puts '  Put the production database password in config/database.yml'
puts '  Change admin user password'
puts '  Put mail server information in mail.rb'
puts '  Put real IP address and git repo URL in deployment files'
puts '  Configure TimeZone in environment.rb'
puts '  Github setup and push'
puts '  rake db:create && rake db:migrate'
