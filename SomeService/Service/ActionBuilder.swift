//
//  ActionBuilder.swift
//  SomeService
//
//  Created by 劉紘任 on 2020/6/8.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import UIKit

public struct Action {
  let title: String
  let style: UIAlertAction.Style
  let action: () -> Void
}

public extension Action {
  static func `default`(_ title: String, action: @escaping () -> Void) -> [Action] {
    return [Action(title: title, style: .default, action: action)]
  }
  
  static func destructive(_ title: String, action: @escaping () -> Void) -> [Action] {
    return [Action(title: title, style: .destructive, action: action)]
  }
  
  static func cancel(_ title: String, action: @escaping () -> Void = {}) -> [Action] {
    return [Action(title: title, style: .cancel, action: action)]
  }
}

public func makeAlertController(title: String,
                                message: String,
                                style: UIAlertController.Style,
                                actions: [Action]) -> UIAlertController {
  let controller = UIAlertController(
    title: title,
    message: message,
    preferredStyle: style
  )
  for action in actions {
    let uiAction = UIAlertAction(title: action.title, style: action.style) { _ in
      action.action()
    }
    controller.addAction(uiAction)
  }
  return controller
}

@_functionBuilder
public struct ActionBuilder {
  
  typealias Component = [Action]
  
  static func buildBlock(_ children: Component...) -> Component {
    return children.flatMap { $0 }
  }
  
  static func buildIf(_ component: Component?) -> Component {
    return component ?? []
  }
  
  static func buildEither(first component: Component) -> Component {
    return component
  }
  
  static func buildEither(second component: Component) -> Component {
    return component
  }
}

public func Alert(title: String,
                  message: String,
                  @ActionBuilder _ makeActions: () -> [Action]) -> UIAlertController {
  makeAlertController(
    title: title,
    message: message,
    style: .alert,
    actions: makeActions()
  )
}

public func ActionSheet(title: String,
                        message: String,
                        @ActionBuilder _ makeActions: () -> [Action]) -> UIAlertController {
  makeAlertController(
    title: title,
    message: message,
    style: .actionSheet,
    actions: makeActions()
  )
}

public func ForIn<S: Sequence>(_ sequence: S,
                               @ActionBuilder makeActions: (S.Element) -> [Action]) -> [Action] {
  return sequence
    .map(makeActions) // of type [[Action]]
    .flatMap { $0 }   // of type [Action]
}

let canEdit = true
let alertController = Alert(title: "Deletion", message: "Are you sure?") {
  Action.default("Delete") { /* ... */ }
  if canEdit {
    Action.destructive("Edit") { /* ... */ }
  } else {
    Action.destructive("Share") { /* ... */ }
  }
  Action.cancel("Cancel")
}

let dynamicAlertController = Alert(title: "Title", message: "Message") {
  ForIn(["Action1", "Action2"]) { string in
    Action.default(string) { print(string) }
  }
}

