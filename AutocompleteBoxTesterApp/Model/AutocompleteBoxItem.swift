//
//  AutocompleteBoxItem.swift
//  AutocompleteBoxTesterApp
//
//  Created by sphota on 1/14/20.
//  Copyright © 2020 alevkov. All rights reserved.
//

import Foundation
import UIKit

class AutocompleteBoxItem {
  var attributedField: NSMutableAttributedString?
  var completeAttributedField: NSMutableAttributedString?
  
  var field: String
  var symbol: String
  var highlightLength: Int
  
  public init(field: String, categorySymbol: String, highlightLength: Int) {
    self.field = field
    self.symbol = categorySymbol
    self.highlightLength = highlightLength
  }
  
  public func formattedItem() -> NSMutableAttributedString {
    completeAttributedField = NSMutableAttributedString()
    let font = UIFont.systemFont(ofSize: 17)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.systemBlue,
    ]
    
    let boldFont = UIFont.boldSystemFont(ofSize: 17)
    let boldAttributes: [NSAttributedString.Key: Any] = [
        .font: boldFont,
        .foregroundColor: UIColor.systemBlue,
    ]
    
    if self.symbol == "#" {
      let attributedSymbol = NSMutableAttributedString(string: self.symbol)
      attributedSymbol.addAttributes(attributes, range: NSRange(location: 0, length: 1))
      completeAttributedField!.append(attributedSymbol)
    }
    
    attributedField = NSMutableAttributedString(string: self.field)
    attributedField!.addAttributes(attributes, range: NSRange(location: 0, length: self.field.count))
    attributedField!.addAttributes(boldAttributes, range: NSRange(location: 0, length: self.highlightLength))
    completeAttributedField!.append(attributedField!)
    
    return completeAttributedField!
  }
}
