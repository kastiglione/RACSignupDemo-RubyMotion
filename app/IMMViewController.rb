class RACSignal
  def self.reduceLatest(*signals, &block)
    raise 'WTF' if signals.size != block.arity
    case block.arity
    when 1 then combineLatest(signals, reduce1: block)
    when 2 then combineLatest(signals, reduce2: block)
    when 3 then combineLatest(signals, reduce3: block)
    when 4 then combineLatest(signals, reduce4: block)
    when 5 then combineLatest(signals, reduce5: block)
    end
  end

  # RubyMotion FIX
  # In RubyMotion, signals for boolean properties are resulting in values of 0 and 1,
  # both of which evaluate as true in Ruby. Consequently the stream is full of true
  # values. The work-around is to explicitly map the values to a boolean.
  # See #to_bool defined below for TrueClass, FalseClass and Fixnum
  def map_to_bool
    map ->(primitive) { primitive.to_bool }
  end
end

[TrueClass, FalseClass].each do |boolClass|
  boolClass.class_exec do
    def to_bool; self end
  end
end

class Fixnum
  def to_bool; self != 0 end
  # Can't overload ! in RubyMotion (operator overloading is ignored on fixnum for performance)
  #def !; puts '! called'; !to_bool end
end

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
    @doNetworkStuff = RACCommand.commandWithCanExecuteSignal(formValid)
    networkResults = @doNetworkStuff.addSignalBlock(->(_) {
      # Wait 3 seconds and then send a random YES/NO.
      RACSignal.interval(3).take(1).sequenceMany -> do
        RACSignal.return(rand(2).to_bool)
      end
    }).switchToLatest.deliverOn(RACScheduler.mainThreadScheduler).map_to_bool

    submit = createButton.rac_signalForControlEvents(UIControlEventTouchUpInside)
    submit.subscribeNext ->(sender) do
      @doNetworkStuff.execute(sender)
    end

    # Create a signal by KVOing the command's canExecute property. The signal
    # starts with the current value of canExecute.
    buttonEnabled = @doNetworkStuff.rac_signalForKeyPath('canExecute', observer: self).startWith(@doNetworkStuff.canExecute).map_to_bool

    # The button's enabledness is driven by whether the command can execute,
    # which means that the form is valid and the command isn't already
    # executing.
    rac_deriveProperty('createButton.enabled', from: buttonEnabled)

    # The button's title color is driven by its enabledness.
    @defaultButtonTitleColor = createButton.titleLabel.textColor
    buttonTextColor = buttonEnabled.map ->(enabled) do
      enabled ? @defaultButtonTitleColor : UIColor.lightGrayColor
    end

    # Update the title color every our text color signal changes. We can't use
    # the RAC macro since the only way to change the title color is by calling
    # a multi-argument method. So we lift the selector into the RAC world
    # instead.
    createButton.rac_liftSelector(:'setTitleColor:forState:', withObjects: buttonTextColor, UIControlStateNormal)

    # Our fields' text color and enabledness is derived from whether our
    # command is executing.
    executing = @doNetworkStuff.rac_signalForKeyPath('executing', observer: self).deliverOn(RACScheduler.mainThreadScheduler).map_to_bool

    fieldTextColor = executing.map ->(is_executing) { is_executing ? UIColor.lightGrayColor : UIColor.blackColor }
    rac_deriveProperty('firstNameField.textColor', from: fieldTextColor)
    rac_deriveProperty('lastNameField.textColor', from: fieldTextColor)
    rac_deriveProperty('emailField.textColor', from: fieldTextColor)
    rac_deriveProperty('reEmailField.textColor', from: fieldTextColor)

    notProcessing = executing.map ->(is_executing) { !is_executing }
    rac_deriveProperty('firstNameField.enabled', from: notProcessing)
    rac_deriveProperty('lastNameField.enabled', from: notProcessing)
    rac_deriveProperty('emailField.enabled', from: notProcessing)
    rac_deriveProperty('reEmailField.enabled', from: notProcessing)

    # Submission ends when the user clicks the button and then executing stops.
    submissionEnded = submit.mapReplace(executing).switchToLatest.filter ->(processing) do
      !processing
    end

    # The submit count increments after submission has ended.
    submitCount = submissionEnded.scanWithStart 0, combine: ->(running, _) do
      running + 1
    end

    # Status label is hidden until after we've had a submission complete.
    rac_deriveProperty('statusLabel.hidden', from: submitCount.startWith(0).map(->(count) {
      count < 1
    }))

    # Derive the status label's text and color from our network result.
    rac_deriveProperty('statusLabel.text', from: networkResults.map(->(success) {
      success ? 'All good!' : 'An error occurred!'
    }))
    rac_deriveProperty('statusLabel.textColor', from: networkResults.map(->(success) {
      success ? UIColor.greenColor : UIColor.redColor
    }))

    UIApplication.sharedApplication.rac_deriveProperty('networkActivityIndicatorVisible', from: executing)
  end
end
