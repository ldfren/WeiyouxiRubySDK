##
# Ruby API for Sina MicroBlog Weiyouxi, 
#    developped on Ruby 1.9.3, and tested on Rails 3.2.3
# By Lead Frenzy (ldfren@gmail.com) MSN:ldfren@hotmail.com  QQ:20294415 http://leadfrenzy.net
# 2012.04.08 v0.0.2
##

## Sample: use it to get user infor in Rails controller
#  require 'WeiyouxiClient'
#  # define your app key & app secret
#	app_key = 1111111111;
#	app_secret = 2222222222;
#  # params hash includes wyx_user_id,wyx_session_key,wyx_create,wyx_expire,wyx_signature keys, which from weibo.com
#  weiyouxiclient = WeiyouxiClient.new(app_key, app_secret, params);
#  @user_info = weiyouxiclient('user/show', { :uid=>33333 });
#  # then you can read user information from @user_info
##

require 'digest'

# define check error exception
class CheckError < StandardError; end

class WeiyouxiClient
  PREFIX_PARAM = 'wyx_';
  VERSION = '0.0.2';
	
  def initialize(source, secret, new_params=nil)
    @apiUrl = 'http://api.weibo.com/game/1/';
    @userAgent = 'Weiyouxi Agent Alpha 0.0.1';
    @connectTimeout = 30;
    @timeout = 30;
		
    if new_params!=nil
      @params = new_params;
    else
      raise ArgumentError, 'Parameters not provided' unless defined? params;
      @params = params;
    end

    @wyx_session = { :sessionKey=>nil, 
		 :userId=>nil, 
		 :create=>nil,
		 :expire=>nil,
		};
    @source = source;
    @secret = secret;
    @sessionKey = @params[(PREFIX_PARAM+'session_key').intern];
    @signature = @params[(PREFIX_PARAM+'signature').intern];

    raise ArgumentError, 'Require source' if @source == nil;
    raise ArgumentError, 'Require secret' if @secret == nil;
	
    #Check signature and session key
    unless @sessionKey == nil || @signature == nil
      self.checkSignature;
      self.checkSessionKey;
    end
  end

  # Used when unable to get parameters from params
  # set and check signature
  def setAndCheckSignature(signature, getParams={})
    @signature = signature;
    self.checkSignature(getParams);
  end

  def checkSignature(getParams={})  
    raise ArgumentError, 'Require signature' if @signature == nil;
		
    temp = getParams.size==0 ? @params:getParams; 
    temp.delete((PREFIX_PARAM+'signature').intern);
	new_params = {};
    temp.each_key do |k|
      new_params[k] = temp[k] if k.to_s.start_with? PREFIX_PARAM;
    end

    baseString = self.buildBaseString(new_params);
    raise CheckError, 'Signature error' if @signature.to_s != Digest::SHA1.hexdigest(baseString.to_s+@secret.to_s).to_s;
  end

  def setAndCheckSessionKey(session_key)
    @sessionKey = session_key;
    self.checkSessionKey();
  end

  def checkSessionKey()
    raise 'Require session key' if @sessionKey == nil;

    @wyx_session[:sessionKey] = @sessionKey;
    sessionArr = @wyx_session[:sessionKey].split('_');
    raise 'Session key error' if sessionArr.length < 3;

    expire = sessionArr[1];
    userId = sessionArr[2];
    @wyx_session[:userId] = userId.to_i;
    @wyx_session[:create] = @params[(PREFIX_PARAM+'create').intern];
    @wyx_session[:expire] = @params[(PREFIX_PARAM+'expire').intern]==nil ? @params[(PREFIX_PARAM+'expire').intern]:expire;
  end

  def getUserId()
    @wyx_session[:userId]
  end

  def getSession()
    @wyx_session
  end

  require 'rubygems'
  require 'json'
  def post(api, data=Hash.new)
    response_str = self.http_conn(@apiUrl+api, self.buildQueryParamStr(data), true);
    puts response_str;
    JSON.parse(response_str); 
  end

  def get(api, data=Hash.new)
    response_str = self.http_conn(@apiUrl+api, self.buildQueryParamStr(data), false);
    puts response_str;
    JSON.parse(response_str);
  end

  def buildQueryParamStr(data)
    timestamp = Time.now.to_f;

    new_params = { :source => @source,
		   :timestamp => timestamp,
		 }
    new_params[:session_key] = @sessionKey if @sessionKey != nil;

    new_params = new_params.merge(data);
    baseString = self.buildBaseString(new_params);
    @signature = Digest::SHA1.hexdigest(baseString + @secret);
    baseString = baseString + '&signature=' + @signature.to_s;
    return baseString;
  end

  def buildBaseString(new_params)
    return '' if new_params==nil || new_params.size==0;
    
    keys = self.urlencodeRfc3986( new_params.keys );
    values = self.urlencodeRfc3986( new_params.values );
    new_params.clear;
    keys.each_index {|i| new_params[keys[i]] = values[i]};
   
    pairs = [];
    sorted_array = new_params.sort;
    sorted_array.each do |value|
      if value[1].is_a? Array
	value[1] = value[1].sort
        value[1].each { |v| pairs += [ value[0]+'='+v ] };
      else
	pairs += [ value[0]+'='+value[1] ];
      end
    end

    pairs.join('&');
  end

  require 'uri'
  def urlencodeRfc3986(input)
    if input.is_a? Array
      res_str = [];
      input.each { |v| res_str += Array.new([self.urlencodeRfc3986(v.to_s)])};
      return res_str;
    elsif input.is_a? String
      input = URI.escape(input);
      input = input.gsub(/[+]/, '%7E');
      input.gsub(/[ ]/, '~');
    else
      return ''
    end
  end

  require 'net/http'
  def http_conn(url, dataStr='', isPost=false)
    httpInfo = [];
    # set options, waiting...
    
    uri = URI(url);
    puts uri.host;
    puts uri.port;
    puts uri.path;
    puts dataStr;
    response = nil;
    Net::HTTP.start(uri.host, uri.port) do |http|      
      if isPost
        response = http.request_post(uri.path, dataStr);
	@httpCode = response.code;
      else
        response = http.request_get(uri.path+"?#{dataStr}");
  	@httpCode = response.code;
      end
    end
    
    return response.body;
  end

  def setUserAgent(agent='')
    @userAgent = agent;
  end

  def setConnectTimeout(time=30)
    @connectTimeout = time;
  end

  def setTimeout(time=30)
    @timeout = time;
  end

  def getHttpCode()
    @httpCode;
  end

  def getHttpInfo()
    @httpInfo;
  end

end
