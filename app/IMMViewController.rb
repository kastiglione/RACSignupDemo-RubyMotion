# Experimental RubyMotion port of Josh Abernathy's (@joshaber) ReactiveCocoa iOS Signup Demo.
#
# https://github.com/joshaber/RACSignupDemo
#
# The RubyMotion macros and hacks are found after this class.
class IMMViewController < UIViewController
  attr_accessor :firstNameField, :lastNameField, :emailField, :reEmailField, :statusLabel, :createButton

  def viewDidLoad
    super

    # Are all entries valid? This is derived entirely from the values of our UI.
    signals = [firstNameField, lastNameField, emailField, reEmailField].collect(&:rac_textSignal)
    formValid = RACSignal.reduceLatest(*signals) do |firstName, lastName, email, reEmail|
      [firstName, lastName, email, reEmail].none?(&:empty?) && email == reEmail
    end

    # Use a command to encapsulate the validity and in-flight check.
    # RubyMotion FIX: store doNetworkStuff in ivar to retain it past method scope; ain't nobody got time for closures
    @doNetworkStuff = RACCommand.commandWithCanExecuteSignal(formValid)
    networkResults = @doNetworkStuff.add_signal { |_|
      # Wait 3 seconds and then send a random YES/NO.
      RACSignal.interval(3).take(1).sequenceMany -> do
        RACSignal.return(rand(2).to_bool)
      end
    }.latest.boolean.main_thread

    submit = createButton.rac_signalForControlEvents(UIControlEventTouchUpInside)
    submit.each! do |sender|
      @doNetworkStuff.execute(sender)
    end

    # Create a signal by KVOing the command's canExecute property. The signal
    # starts with the current value of canExecute.
    buttonEnabled = rac(@doNetworkStuff).canExecute.startWith(@doNetworkStuff.canExecute).boolean

    # The button's enabledness is driven by whether the command can execute,
    # which means that the form is valid and the command isn't already
    # executing.
    rac.createButton.enabled = buttonEnabled

    # The button's title color is driven by its enabledness.
    @defaultButtonTitleColor = createButton.titleLabel.textColor
    buttonTextColor = buttonEnabled.flip_flop(@defaultButtonTitleColor, UIColor.lightGrayColor)

    # Update the title color every our text color signal changes. We can't use
    # the RAC macro since the only way to change the title color is by calling
    # a multi-argument method. So we lift the selector into the RAC world
    # instead.
    rac.createButton.setTitleColor(buttonTextColor, forState: UIControlStateNormal)

    # Our fields' text color and enabledness is derived from whether our
    # command is executing.
    executing = rac(@doNetworkStuff).executing.boolean.main_thread

    %w[firstNameField lastNameField emailField reEmailField].each do |field|
      rac.key(field).textColor = executing.flip_flop(UIColor.lightGrayColor, UIColor.blackColor)
      rac.key(field).enabled = executing.negate
    end

    # Submission ends when the user clicks the button and then executing stops.
    submissionEnded = submit.mapReplace(executing).latest.filter! do |processing|
      !processing
    end

    # The submit count increments after submission has ended.
    submitCount = submissionEnded.scanWithStart 0, combine: ->(running, _) do
      running + 1
    end

    # Status label is hidden until after we've had a submission complete.
    rac.statusLabel.hidden = submitCount.startWith(0).map! do |count|
      count < 1
    end

    # Derive the status label's text and color from our network result.
    rac.statusLabel.text = networkResults.flip_flop('All good!', 'An error occurred!')
    rac.statusLabel.textColor = networkResults.flip_flop(UIColor.greenColor, UIColor.redColor)

    rac(UIApplication.sharedApplication).networkActivityIndicatorVisible = executing
  end
end

class RACSignal
  # RubyMotion's bridge support does not handle Objective-C methods that take block
  # arguments typed as id so as to take blocks of varying arity. To work around this,
  # an Objective-C category has been created with numbered methods, each explicitly
  # typed, which pass the arguments to the original method.
  #
  # The same work-around will be required for all other methods that take an id block.
  def self.reduceLatest(*signals, &block)
    raise "Block must take #{signals.size} arguments to match the number of signals." if signals.size != block.arity
    case block.arity
    when 1 then combineLatest(signals, reduce1: block)
    when 2 then combineLatest(signals, reduce2: block)
    when 3 then combineLatest(signals, reduce3: block)
    when 4 then combineLatest(signals, reduce4: block)
    when 5 then combineLatest(signals, reduce5: block)
    end
  end

  # In RubyMotion, signals for boolean properties are resulting in values of 0 and 1,
  # both of which evaluate as true in Ruby. Consequently the stream is full of true
  # values. The work-around is to explicitly map the values to a boolean.
  # See #to_bool defined below for TrueClass, FalseClass and Fixnum
  def boolean
    map ->(primitive) { primitive.to_bool }
  end

  # Create ! versions of a few ReactiveCocoa methods, allowing the methods to take
  # a block the Ruby way and avoid explicit lambda expressions.
  # This conflicts with the common semantics of using ! to imply the method modifies
  # the receiver, but the alternatives (ex: map_, map?) are less appealing.
  def map!(&block)
    map(block)
  end

  def filter!(&block)
    filter(block)
  end

  def each!(&block)
    subscribeNext(block)
  end
  alias_method :each, :each!

  def add_signal(&block)
    addSignalBlock(block)
  end

  def main_thread
    deliverOn(RACScheduler.mainThreadScheduler)
  end

  def latest
    switchToLatest
  end

  # Map a signal of truth values to a true value and false value.
  def flip_flop(trueValue, falseValue)
    map! do |truth|
      truth ? trueValue : falseValue
    end
  end

  # If possible, this would overload the ! operator. A RubyMotion bug has been filed.
  def negate
    map! { |truth| !truth }
  end
end

[TrueClass, FalseClass].each do |boolClass|
  boolClass.class_exec do
    def to_bool; self end
  end
end

class Fixnum
  def to_bool; self != 0 end
end

class RACMotionKeyPathAgent
  def initialize(object, observer)
    @object = object
    @observer = observer
    @keyPath = []
  end

  def key(key)
    @keyPath << key.to_s
    self
  end

  def method_missing(method, *args)
    # Conclude when the method corresponds to a RACSignal method; see to RACAble() macro
    if RACSignal.method_defined?(method)
      @object.rac_signalForKeyPath(keyPath, observer: @observer).send(method, *args)

    # Conclude when assigning a signal; see RAC() macro
    elsif args.size == 1 && args.first.is_a?(RACSignal) && method.to_s.end_with?('=')
      key(method)
      @object.rac_deriveProperty(keyPath.chop, from: args.first)

    # Conclude when calling a non-RAC method with a signal argument, lift it
    elsif !@keyPath.empty? && args.any? { |arg| arg.is_a?(RACSignal) }
      # method_missing sets method to just the first argument's portion of the called selector.
      # Construct the full selector. Obviously works only for Objective-C methods.
      options = args.last.is_a?(Hash) ? args.pop : {}
      selector = [method].concat(options.keys).join(':') << ':'
      objects = args.concat(options.values)
      target = @object.valueForKeyPath(keyPath)
      if target.respondsToSelector(selector)
        # RubyMotion can't splat an array into a varags paramter. Case it out.
        o = objects
        case objects.size
        when 2 then target.rac_liftSelector(selector, withObjects: o[0], o[1])
        when 3 then target.rac_liftSelector(selector, withObjects: o[0], o[1], o[2])
        when 4 then target.rac_liftSelector(selector, withObjects: o[0], o[1], o[3], o[4])
        end
      else
        raise "#{target.inspect} (via keyPath '#{keyPath}') does not respond to `#{selector}`"
      end

    # Continue when simple getter is called and extend the key path
    else
      key(method)
    end
  end

  def keyPath
    @keyPath.join('.')
  end
  alias_method :to_s, :keyPath
end

class Object
  def rac(object=self)
    RACMotionKeyPathAgent.new(object, self)
  end
  # Capitalized doesn't work as well due to the required () to avoid it being treated as a constant
  alias_method :RAC, :rac
end
