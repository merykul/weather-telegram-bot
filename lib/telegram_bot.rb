require 'telegram/bot'
require_relative 'weather'
require 'yaml'

class TelegramBot
  config = YAML.load_file('config.yml')
  TOKEN = config['telegram_bot_token']
  @user_states = {}

  def initialize_user_states
    @user_states ||= {}
  end

  def run
    initialize_user_states

    bot.listen do |message|
      begin
        user_id = message.chat.id
        puts "Received message from user #{user_id}"
        puts "User state: #{@user_states[user_id]}"

        case message
        when Telegram::Bot::Types::Message
          handle_message(message)
        when Telegram::Bot::Types::CallbackQuery
          handle_callback(message)
        end
      rescue => e
        puts 'Error ---------------------------------------------------------------------------------------------------------'
        puts e
        puts '---------------------------------------------------------------------------------------------------------------'
        puts 'Backtrace: ----------------------------------------------------------------------------------------------------'
        puts e.backtrace.join("\n")
        puts '---------------------------------------------------------------------------------------------------------------'
      end
    end
  end

  private

  def bot
    Telegram::Bot::Client.run(TOKEN) { |bot| return bot }
  end

  def weather_message(city_name, chat_id)
    if city_name.nil? || city_name == '/start'
      bot.api.send_message(chat_id: chat_id, text: 'Please enter a valid city name.')
      return
    end

    send_message(chat_id, Weather.new(city_name).form_message)
  end

  def handle_message(message)
    user_id = message.chat.id

    if @user_states[user_id] == 'awaiting_city'
      city = message.text
      bot.api.send_message(chat_id: message.chat.id, text: weather_message(city, message.chat.id))
      @user_states[user_id] = nil # Reset state after handling
    else
      case message.text
      when '/start'
        send_start_message(message)
      when '/stop'
        send_bye_message(message)
      else
        puts 'Unhandled message'
      end
    end
  end

  def handle_callback(message)
    user_id = message.message.chat.id
    puts "Received callback query from user #{user_id} with data #{message.data}"
    callback_data = message.data

    case callback_data
    when 'weather'
      bot.api.send_message(chat_id: message.message.chat.id, text: 'Please enter the city name:')

      @user_states[user_id] = 'awaiting_city'
      puts "User state: #{@user_states[user_id]}"
    else
      puts "Unhandled callback data: #{callback_data}"
    end
  end

  def send_start_message(message)
    buttons = [
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Temperature in my city', callback_data: 'weather')]
    ]
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}, let's start!", reply_markup: markup)
  end

  def send_bye_message(message)
    bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
  end
end
