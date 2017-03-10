# rails-specific support methods

# how to use:
#

def create_user
  FG.create(:user)
end

def create_team
  FG.create(:team)
end

def input_member(user, team)
  Membership.create team: team, user: user, rank: 'ACT'
end

# use this in requests specs, on controllers that use 'authenticate_member_with_basic_auth'
# cred = basic_auth("joe_smith")
# get '/path', nil, {'HTTP_AUTHORIZATION' => cred}
def basic_auth(username, password='welcome')
  create_user
  ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
end

# use this in requests specs, on controllers that use 'authenticate_member_with_basic_auth'
def http_login(username, password = 'welcome')
  create_user
  request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username,password)
end

# use this with feature specs
def capy_user_login(input_user = nil)
  user = input_user || create_user
  team = Team.count > 0 ? Team.first : create_team
  mem  = input_member(user, team)
  login_with(user)
end

def capy_member_login(input_member)
  user = input_member.user
  login_with(user)
end

def capy_create_member_and_login(current_team)
  user   = create_user
  member = Membership.create team: current_team, user: user, rank: 'ACT'
  login_with(user)
end

def login_with(user)
  visit login_path
  fill_in 'user_user_name', :with => user.user_name
  fill_in 'user_password',  :with => 'smso'
  click_button 'Log In'
  user
end

# ----- request specs -----

def _breakout(mem, pwd)
  [ mem.team, {user: {user_name: mem.user.user_name, password: pwd}} ]
end

# for single-session testing
def request_login(member, password = 'smso')
  team, opts = _breakout(member, password)
  post("https://#{team.fqdn}#{sessions_path}", {params: opts})
end

# for multi-session testing
def request_login_session(member, password = 'smso')
  team, opts = _breakout(member, password)
  open_session do |s|
    s.post("https://#{team.fqdn}#{sessions_path}", params: opts)
  end
end

# for feature specs
def set_host_url(team, org)
  Team.current_id       = team.id
  Capybara.default_host = "http://#{team.subdomain}.#{org.domain}"
end

# how to use:
# describe 'Inbound Letter Opener' do
#   include_context 'Integration Environment'
#   ...
RSpec.shared_context 'Integration Environment' do
  let(:orgn)   { FG.create(:org)                                             }
  let(:team1)  { FG.create(:team, org_id: orgn.id)                           }
  let(:team2)  { FG.create(:team, org_id: orgn.id)                           }
  let(:pagr1)  { Pgr.create(team_id: team1.id)                               }
  let(:pagr2)  { Pgr.create(team_id: team2.id)                               }
  let(:usr1)   { FG.create(:user_with_phone_and_email)                       }
  let(:usr2)   { FG.create(:user_with_phone_and_email)                       }
  let(:usr3)   { FG.create(:user_with_phone_and_email)                       }
  let(:mem1)   { FG.create(:membership, team_id: team1.id, user_id: usr1.id) }
  let(:mem2)   { FG.create(:membership, team_id: team1.id, user_id: usr2.id) }
  let(:mem3)   { FG.create(:membership, team_id: team2.id, user_id: usr3.id) }
  let(:mmail1) { mem1; "#{usr1.user_name}@#{team1.fqdn}"                     }
  let(:mmail2) { mem2; "#{usr2.user_name}@#{team1.fqdn}"                     }
  let(:mmail3) { mem3; "#{usr3.user_name}@#{team2.fqdn}"                     }
  let(:email1) { mem1; usr1.emails.first.address                             }
  let(:email2) { mem2; usr2.emails.first.address                             }
  let(:email3) { mem3; usr3.emails.first.address                             }
  let(:team1_url) { "https://#{team1.fqdn}"                                  }
  let(:team2_url) { "https://#{team2.fqdn}"                                  }
  let(:partnership) do
    opts = {team_id: team1.id, partner_id: team2.id, status: 'accepted'}
    TeamPartnership.create(opts)
  end
end

def hydrate(*args); end

# ----- misc methods -----

def run_rake_task(task_name, *args)
  rake_application[task_name].invoke(*args)
end

def rake_application
  require 'rake'
  @rake_application ||= Rake.application.tap do |app|
    # app.handle_options
    app.load_rakefile
  end
end

def pager_address(mem)
  "#{mem.user_name}@#{mem.team.fqdn}"
end

# ----- ajax helper -----

module WaitForAjax
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    value = page.evaluate_script('jQuery.active')
    value.zero?
  end
end

RSpec.configure do |config|
  config.include WaitForAjax, type: :feature
end
