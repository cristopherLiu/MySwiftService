//
//  SwiftTimer.swift
//  SomeService
//
//  Created by 劉紘任 on 2020/6/8.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import Foundation

public class SwiftTimer {
  
  private let internalTimer: DispatchSourceTimer
  
  private var isRunning = false
  
  public let repeats: Bool
  
  public typealias SwiftTimerHandler = (SwiftTimer) -> Void
  
  private var handler: SwiftTimerHandler
  
  public init(interval: DispatchTimeInterval, repeats: Bool = false, leeway: DispatchTimeInterval = .seconds(0), queue: DispatchQueue = .main , handler: @escaping SwiftTimerHandler) {
    
    self.handler = handler
    self.repeats = repeats
    internalTimer = DispatchSource.makeTimerSource(queue: queue)
    internalTimer.setEventHandler { [weak self] in
      if let strongSelf = self {
        
        DispatchQueue.main.async {
          handler(strongSelf)
        }
      }
    }
    
    if repeats {
      internalTimer.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
    } else {
      internalTimer.schedule(deadline: .now() + interval, leeway: leeway)
    }
  }
  
  public static func repeaticTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .seconds(0), queue: DispatchQueue = .main , handler: @escaping SwiftTimerHandler ) -> SwiftTimer {
    return SwiftTimer(interval: interval, repeats: true, leeway: leeway, queue: queue, handler: handler)
  }
  
  deinit {
    if !self.isRunning {
      internalTimer.resume()
    }
  }
  
  //You can use this method to fire a repeating timer without interrupting its regular firing schedule. If the timer is non-repeating, it is automatically invalidated after firing, even if its scheduled fire date has not arrived.
  public func fire() {
    if repeats {
      handler(self)
    } else {
      handler(self)
      internalTimer.cancel()
    }
  }
  
  public func start() {
    if !isRunning {
      internalTimer.resume()
      isRunning = true
    }
  }
  
  public func suspend() {
    if isRunning {
      internalTimer.suspend()
      isRunning = false
    }
  }
  
  public func rescheduleRepeating(interval: DispatchTimeInterval) {
    if repeats {
      internalTimer.schedule(deadline: .now() + interval, repeating: interval)
    }
  }
  
  public func rescheduleHandler(handler: @escaping SwiftTimerHandler) {
    self.handler = handler
    internalTimer.setEventHandler { [weak self] in
      if let strongSelf = self {
        handler(strongSelf)
      }
    }
    
  }
}

//MARK: Throttle
public extension SwiftTimer {
  
  private static var timers = [String:DispatchSourceTimer]()
  
  static func throttle(interval: DispatchTimeInterval, identifier: String, queue: DispatchQueue = .main , handler: @escaping () -> Void ) {
    
    if let previousTimer = timers[identifier] {
      previousTimer.cancel()
      timers.removeValue(forKey: identifier)
    }
    
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timers[identifier] = timer
    timer.schedule(deadline: .now() + interval)
    timer.setEventHandler {
      handler()
      timer.cancel()
      timers.removeValue(forKey: identifier)
    }
    timer.resume()
  }
  
  static func cancelThrottlingTimer(identifier: String) {
    if let previousTimer = timers[identifier] {
      previousTimer.cancel()
      timers.removeValue(forKey: identifier)
    }
  }
}
