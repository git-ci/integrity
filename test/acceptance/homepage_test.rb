require "helper/acceptance"
require 'timecop'

class HomepageTest < Test::Unit::AcceptanceTestCase
  story <<-EOS
    As a user,
    I want to browse my project from Integrity's homepage
    So I can follow the status of my various projects
  EOS

  scenario "I can login on the very first page" do
    visit "/"
    click_link "Login"

    assert_equal 401, response_code
    assert_have_tag("a[@href='/login']", :content => "try again")
    assert_have_tag("a[@href='/']",      :content => "go back")
  end

  scenario "I can login on projects list page" do
    Project.gen(:my_test_project, :public => true)
    visit "/"
    click_link "Login"

    assert_equal 401, response_code
    assert_have_tag("a[@href='/login']", :content => "try again")
    assert_have_tag("a[@href='/']",      :content => "go back")
  end

  scenario "Private projects aren't shown" do
    Project.gen(:my_test_project, :public => false)
    Project.gen(:integrity, :public => true)

    visit "/"

    assert_have_no_tag("a", :content => "My Test Project")
    assert_have_tag("a", :content => "Integrity")
  end

  scenario "I can see the state of my various projects" do
    # Freeze time because build time keeps growing otherwise
    time = Time.now
    Timecop.freeze(time) do
      Project.gen(:successful)
      Project.gen(:failed)
      project = Project.gen(:building)
      # Need to adjust build start time, otherwise the project appears to
      # have been building for years
      build = project.last_build
      build.started_at = time - 2 * 60
      build.save!
      Project.gen(:blank)

      visit "/"

      # TODO
      assert_have_tag("li[@class~=success]",  :content => "successfully in 2m")
      assert_have_tag("li[@class~=failed]",   :content => "and failed in 2m")

      assert_have_tag("li[@class~=blank]",    :content => "Never built yet")
      assert_have_tag("li[@class~=building]", :content => "Building for")
      
      # http://stackoverflow.com/questions/1474045/finding-a-label-with-webrat-that-contains-a-link
      # field is not defined here, thus convert css query to xpath
      field = field_by_xpath('//li[contains(@class,"building")]')
      # and what that returns is a TextField which is not at all what I want
      text = field.element.text
      # fold whitespace
      text = text.gsub!(/\s+/, ' ')
      # finally check the content
      assert text =~ /Building for 2m/
    end
  end

  scenario "Clicking on a project from the homepage" do
    Project.gen(:my_test_project, :public => true)

    visit "/"
    click_link "My Test Project"

    assert_have_tag("h1", :content => "My Test Project")

    click_link "projects"

    assert_have_tag("a", :content => "My Test Project")
  end

  scenario "Browsing to an unknown project" do
    visit "/foobiz"
    assert last_response.not_found?
    assert_have_tag("h1", :content => "you seem a bit lost")
  end

  scenario "Browsing to a private project" do
    Project.gen(:name => "Secret", :public => false)

    visit "/secret"
    assert_equal 401, last_response.status
    assert_have_tag("h1", :content => "know the password?")
  end

  scenario "Signing-in as an admin and browsing to a private project" do
    Project.gen(:my_test_project, :public => false)

    login_as "admin", "test"
    visit "/"
    click_link "My Test Project"
    assert_have_tag("h1", :content => "My Test Project")
  end
end
