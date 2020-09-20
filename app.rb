require 'sinatra'
require 'rest-client'
require 'json'

class Zoho
    def initialize
        @refresh_token = 'xxxxxxxxxxxxxxxxxxxxx'
        @client_id = 'xxxxxxxxxxxxxxxxxxxxxxxx'
        @client_secret = 'xxxxxxxxxxxxxxxxxxxxx'
        @access_token = File.read('access_token.txt')
        refresh_token if @access_token.empty? || Time.now - File.mtime("access_token.txt") > 3500
    end
 
    def refresh_token
        endpoint = "https://accounts.zoho.com.au/oauth/v2/token?refresh_token=#{@refresh_token}&client_id=#{@client_id}&client_secret=#{@client_secret}&grant_type=refresh_token"
        response = RestClient.post(endpoint, {})
        @access_token = JSON.parse(response)['access_token']
        File.write('access_token.txt', @access_token)
    end
    
    def rest(method, endpoint, payload='')
        begin
            RestClient::Request.execute(
               :method => method,
               :url => endpoint,
               :headers => { :Authorization => "Zoho-oauthtoken #{@access_token}" },
               :payload => payload
            )
        rescue RestClient::Unauthorized
            refresh_token
            '{"data":[]}'
        end
    end
end

class ContactsManager
    def initialize
        @zoho = Zoho.new
        @endpoint = 'https://www.zohoapis.com.au/crm/v2/contacts'
    end
    
    def get(id)
        @zoho.rest(:get, "#{@endpoint}/#{id}")
    end
    
    def list
        @zoho.rest(:get, "#{@endpoint}?fields=First_Name,Last_Name,Email,Phone,Mobile,Title,Mailing_Street,Mailing_Zip,Mailing_Country")
    end
    
    def create(data)
        response = @zoho.rest(:post, @endpoint, JSON(data: [data['0']]).to_s)
        id = JSON(response)['data'][0]['details']['id']
        get(id)
    end
    
    def update(data)
        id = data.keys[0]
        data[id][:id] = id
        contact = JSON({ 'data' => [data[id]] }).to_s
        @zoho.rest(:put, @endpoint, contact)
        contact
    end
    
    def delete(id)
        @zoho.rest(:delete, "#{@endpoint}/#{id}")
        "{}"
    end
end

class App < Sinatra::Base
    contacts = ContactsManager.new
    
    get '/' do
      erb :index
    end
    
    get '/contacts' do
        contacts.list
    end
    
    post '/contacts' do
        case params[:action]
        when "create"
            contacts.create(params[:data])
        when "edit"
            contacts.update(params[:data])
        when "remove"
            contacts.delete(params[:data].keys[0])
        end
    end
end