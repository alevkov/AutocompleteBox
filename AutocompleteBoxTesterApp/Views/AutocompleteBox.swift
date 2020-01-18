//
//  AutocompleteBox.swift
//  AutocompleteBoxTesterApp
//
//  Created by sphota on 1/13/20.
//  Copyright © 2020 alevkov. All rights reserved.
//

import Foundation
import UIKit
import CoreData

// MARK: - UITextView Subclass

class AutocompleteBox: UITextView, UITextViewDelegate {
  var dummyData: [QueryData] = [QueryData]()
  var autocompleteTableItems: [AutocompleteBoxItem] = [AutocompleteBoxItem]()
  var tableView: UITableView?
  var autocompleteFlag: Bool = false
  var selectingFromRowFlag: Bool = false
  var completedAutocompletions: [String] = [String]()
  var currentAutocompletionRange: NSRange?
  var currentCategory: Category?
  
  private let magicChar: Character = "\u{feff}" // "©" // sentinel character
  private let cellIdentifier: String = "AutocompleteBoxCell"
  private let categories: [Category: Int] = [.hashtag: 1, .atMention: 2, .relation: 3]
  private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
    self.delegate = self // there's gotta be a better way!
  }
  
  // MARK: - Overrides
  
  open override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    self.tableView?.removeFromSuperview()
  }
  
  override open func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    NotificationCenter.default.addObserver(self, selector: #selector(AutocompleteBox.textViewDidChange), name: UITextView.textDidChangeNotification, object: self)
  }
  
  override func draw(_ rect: CGRect) {
    self.initTableView()
  }
  
  // MARK: - Event Handlers
  
  @objc open func textViewDidChange() {
    if let cursorRange = self.selectedTextRange {
      
      self.autocompleteTableItems = [] // Reset table items.
      if let autocompleteEndIdx = isEditingAutocompletion() { // Are we currently in an incomplete autocompletion?
        // Get the autocompletion category, partial text and range of partial text.
        let (category, partial, range) = getPartialTriggerText(magicCharIdx: autocompleteEndIdx)
        
        if let category = category, let partial = partial, let range = range {
          self.currentAutocompletionRange = range
          self.currentCategory = category
          let singlePos = self.position(from: cursorRange.start, offset: -1)
          if let singlePos = singlePos, let rangeSingleBefore = self.textRange(from: singlePos, to: cursorRange.start) {
            let token = self.text(in: rangeSingleBefore)
            if (token == " " && category == .hashtag) || token == "\n" { // Complete the autocompletion if we hit space with a hashtag.
              self.completedAutocompletions.append(category.rawValue + partial.dropLast())
              self.completeAutocompletion(token: token)
              self.reHighlightAutocompletions()
              return
            }
          }
          if self.selectingFromRowFlag {
            self.selectingFromRowFlag = false
            return
          }
          self.highlightPartialAutocompletion(range: range)
          self.getAutocompleteItems(category: category, query: partial)
        } else {
          let end = self.position(from: cursorRange.start, offset: 1)
          if let end = end {
            let magicRange = self.textRange(from: cursorRange.start, to: end)
            self.replace(magicRange!, withText: "")
            self.refreshTableView()
            return
          }
        }
      }
      
      // Detect trigger symbols.
      let doublePos = self.position(from: cursorRange.start, offset: -Category.relation.rawValue.count)
      let singlePos = self.position(from: cursorRange.start, offset: -Category.hashtag.rawValue.count)
      
      if let singlePos = singlePos, let rangeSingleBefore = self.textRange(from: singlePos, to: cursorRange.start) {
        let token = self.text(in: rangeSingleBefore)
        if let _ = Category(rawValue: token!) {
          self.insertMagicChar()
        }
      }
      
      if let doublePos = doublePos, let rangeDoubleBefore =  self.textRange(from: doublePos, to: cursorRange.start) {
        let token = self.text(in: rangeDoubleBefore)
        if let _ = Category(rawValue: token!) {
          self.insertMagicChar()
        }
      }
      self.refreshTableView()
      self.tableView?.isHidden = false
    }
  }
  
  // Annoying that we have to set ourselves to be the delegate, just for this...
  // Why can't we receive a notification?
  func textViewDidChangeSelection(_ textView: UITextView) {
    if let cursorRange = self.selectedTextRange {
      guard let singlePos = self.position(from: cursorRange.start, offset: -1) else {
        return
      }
      guard let range = self.textRange(from: singlePos, to: cursorRange.start) else {
        return
      }
      
      let token = self.text(in: range)
      guard token == String(magicChar) else {
        return
      }
      
      if self.autocompleteFlag {
        self.autocompleteFlag = false
      } else {
        self.selectedTextRange = self.textRange(from: singlePos, to: singlePos)
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func insertMagicChar() {
    guard let cursorRange = self.selectedTextRange else {
      return
    }
      
    guard let magicRange = self.textRange(from: cursorRange.start, to: cursorRange.end) else {
      return
    }
    self.autocompleteFlag = true
    // Add sentinel char to text
    self.replace(magicRange, withText: String(magicChar))
    // Set cursor pos before sentinel char
    self.selectedTextRange = self.textRange(from: cursorRange.start, to: cursorRange.start)
  }
  
  private func completeAutocompletion(token: String?) {
    guard let token = token else {
      return
    }
    
    guard let cursorRange = self.selectedTextRange else {
      return
    }
    
    let singlePos = self.position(from: cursorRange.start, offset: 1)
    if let singlePos = singlePos, let magicRange = self.textRange(from: cursorRange.start, to: singlePos) {
      self.replace(magicRange, withText: "")
    }
    
    if token == "\n" || token == " " {
      self.deleteBackward()
    }
    
    self.currentCategory = nil
    self.currentAutocompletionRange = nil
  }
  
  private func isEditingAutocompletion() -> Int? {
    guard let textAfterCursor = self.text(in: self.textRange(from: self.selectedTextRange!.end, to: self.endOfDocument)!) else {
      return nil
    }
    guard let textBeforeCursor = self.text(in: self.textRange(from: self.beginningOfDocument, to: self.self.selectedTextRange!.end)!) else {
      return nil
    }
    
    // If no sentinel, we're done.
    if !textAfterCursor.contains(magicChar) {
      return nil
    }
    
    // Get index of sentinel from origin.
    let idx = (textBeforeCursor.count - 1) + Array(textAfterCursor).firstIndex(of: magicChar)!
    let split = textAfterCursor.split(separator: magicChar, maxSplits: 1, omittingEmptySubsequences: false)
    
    if split.count == 0 {
      return idx
    }
    
    // We don't want to interfere with some other autocompletion happening elsewhere.
    if split[0].contains(Category.hashtag.rawValue) ||
      split[0].contains(Category.atMention.rawValue) ||
      split[0].contains(Category.relation.rawValue) {
      return nil
    }
    
    return idx
  }
  
  private func getPartialTriggerText(magicCharIdx: Int) -> (Category?, String?, NSRange?) {
    guard let textBeforeCursor = self.text(in: self.textRange(from: self.beginningOfDocument, to: self.selectedTextRange!.end)!) else {
      return (nil, nil, nil)
    }
    
    var idxOrderingDict: [Int: String] = [:]
    if let hashtagLastIdx = Array(textBeforeCursor).lastIndex(of: Category.hashtag.rawValue[0]) {
      idxOrderingDict[hashtagLastIdx] = Category.hashtag.rawValue
    }
    if let atMentionLastIdx = Array(textBeforeCursor).lastIndex(of: Category.atMention.rawValue[0]) {
      idxOrderingDict[atMentionLastIdx] = Category.atMention.rawValue
    }
    if let relationLastIdx = Array(textBeforeCursor).lastIndex(of: Category.relation.rawValue[0]) {
      idxOrderingDict[relationLastIdx] = Category.relation.rawValue
    }
    
    let sortedKeys = Array(idxOrderingDict.keys).sorted(by: >)
    
    // Deleting an empty hashtag (no characters added)
    if sortedKeys.count == 0 {
      return (nil, nil, nil)
    }
    
    let trigger = idxOrderingDict[sortedKeys[0]]
    let category = Category(rawValue: trigger ?? "")
    
    // Deleting an empty hashtag (no characters added)
    if magicCharIdx == sortedKeys[0] {
      return (category, nil, nil)
    }
    
    // Deleting an empty hashtag (special case: relation)
    if magicCharIdx == (sortedKeys[0] + 1) && (category == .relation) {
      return (category, nil, nil)
    }
    
    // Grab text of incomplete autocompletion
    let startLoc = sortedKeys[0] + (category == .relation ? 2 : 1)
    let text = String(self.text[startLoc...magicCharIdx])
    // This will be the range to highlight
    let entireAutocompletionRange = NSRange(location: startLoc - 1, length: text.count + 1)
    return (category, text, entireAutocompletionRange)
  }
  
  private func highlightPartialAutocompletion(range: NSRange) {
    let attrStr = NSMutableAttributedString(string:self.text)
    
    let savedPos = self.selectedRange
    var newRange = range
    if self.currentCategory == .relation {
      newRange = NSRange(location: range.location-1, length: range.length + 1)
    }
    attrStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.blue, range: newRange)
    
    self.attributedText = attrStr
    self.selectedRange = savedPos
  }
  
  private func reHighlightAutocompletions() {
    // Reset highlighting
    let savedPos = self.selectedRange
    let attributed = NSMutableAttributedString(string: self.text)
    
    self.attributedText = attributed
    self.selectedRange = savedPos
    
    //    let location = offset(from: beginningOfDocument, to: beginningOfDocument)
    //    let length = offset(from: beginningOfDocument, to: endOfDocument)
    
    // TODO: - Highlight all completed autocompletions.
  }
  
  private func populateRegexMatches(arrayToPopulate: Array<String>, pattern: String) -> Array<String> {
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    var results = arrayToPopulate
    
    regex.enumerateMatches(in: self.text, options: [], range: NSMakeRange(0, self.text.utf16.count)) { result, flags, stop in
      if let r = result?.range(at: 1), let range = Range(r, in: self.text) {
        results.append(String(self.text[range]))
      }
    }
    
    return results
  }
  
  private func getAutocompleteItems(category: Category, query: String) {
    let catValue: Int = self.categories[category]!
    var tablePredicate: NSPredicate?
    if category == .relation {
      tablePredicate = NSPredicate(format: "(category = %d) AND (value = %@)", catValue, query)
    } else {
      tablePredicate = NSPredicate(format: "(category = %d) AND (value BEGINSWITH %@)", catValue, query)
    }
    let request: NSFetchRequest<QueryData> = QueryData.fetchRequest()
    request.predicate = tablePredicate
    
    do {
      self.dummyData = try self.context.fetch(request)
    } catch {
      print("Error while fetching data: \(error)")
    }
    
    self.autocompleteTableItems = []
    
    for i in 0 ..< self.dummyData.count {
      var item: AutocompleteBoxItem?
      if category == .relation {
        item = AutocompleteBoxItem(field: self.dummyData[i].relatedMetadata!, categorySymbol: category.rawValue, highlightLength: query.count)
      } else {
        item = AutocompleteBoxItem(field: self.dummyData[i].value!, categorySymbol: category.rawValue, highlightLength: query.count)
      }
      self.autocompleteTableItems.append(item!)
    }
    
    tableView?.reloadData()
  }
  
  // To position table right below cursor -- might be a future improvement.
  /*
  func cursorRect() -> CGRect? {
    if let selectedRange = self.selectedTextRange {
      let caretRect = self.caretRect(for: selectedRange.end)
      let windowRect = self.convert(caretRect, to: nil)
      
      return windowRect
    }
    
    return nil
  }*/
}

// MARK: - Extension for UITableView handling

extension AutocompleteBox: UITableViewDelegate, UITableViewDataSource {
  func initTableView() {
    self.clearData()
    self.populateStorageWithDummyData()
    tableView = UITableView(frame: CGRect.zero)
    tableView?.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    tableView?.delegate = self
    tableView?.dataSource = self
    self.window?.addSubview(tableView!)
    self.refreshTableView()
  }
  
  func refreshTableView() {
    if let tableView = tableView {
      superview?.bringSubviewToFront(tableView)
      var tableHeight: CGFloat = 0
      tableHeight = tableView.contentSize.height
      
      // Set a bottom margin of 10p
      if tableHeight < tableView.contentSize.height {
        tableHeight -= 10
      }
      
      // Set tableView frame
      var tableViewFrame = CGRect(x: 0, y: 0, width: frame.size.width - 4, height: tableHeight)
      tableViewFrame.origin = self.convert(tableViewFrame.origin, to: nil)
      tableViewFrame.origin.x += 2
      tableViewFrame.origin.y += frame.size.height + 2
      UIView.animate(withDuration: 0.2, animations: { [weak self] in
        self?.tableView?.frame = tableViewFrame
      })
      
      //Setting tableView style
      tableView.layer.masksToBounds = true
      tableView.separatorInset = UIEdgeInsets.zero
      tableView.layer.cornerRadius = 0.0
      tableView.layer.borderColor = UIColor.darkGray.cgColor
      tableView.layer.borderWidth = 1.0
      tableView.separatorColor = UIColor.gray
      tableView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.8)
      
      if self.isFirstResponder {
        superview?.bringSubviewToFront(self)
      }
      tableView.reloadData()
    }
  }
  
  // MARK: TableViewDelegate methods
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.autocompleteTableItems.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
    cell.backgroundColor = UIColor.clear
    cell.textLabel?.attributedText = self.autocompleteTableItems[indexPath.row].formattedItem()
    return cell
  }
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.isHidden = true
    let beginning = self.beginningOfDocument
    var start: UITextPosition?
    var end: UITextPosition?
    if self.currentCategory == .relation {
      start = self.position(from: beginning, offset: currentAutocompletionRange!.location - 1)
      end = self.position(from: start!, offset: currentAutocompletionRange!.length + 1)
    } else {
      start = self.position(from: beginning, offset: currentAutocompletionRange!.location)
      end = self.position(from: start!, offset: currentAutocompletionRange!.length)
    }

    let selectedText = self.autocompleteTableItems[indexPath.row].field
    self.selectingFromRowFlag = true
    if let start = start, let end = end, let range = self.textRange(from: start, to: end) {
      self.replace(range, withText: self.currentCategory!.rawValue + selectedText)
      self.completedAutocompletions.append(self.currentCategory!.rawValue + selectedText)
      self.reHighlightAutocompletions()
      self.completeAutocompletion(token: "")
      self.endEditing(true)
    }
  }
  
  // MARK: - Dummy Data
  
  func populateStorageWithDummyData() {
    let a = QueryData(context: self.context)
    a.category = 1
    a.value = "idea"
    
    let a1 = QueryData(context: self.context)
    a1.category = 1
    a1.value = "idle"
    
    let b = QueryData(context: self.context)
    b.category = 2
    b.value = "Jacob Cole"
    
    let b1 = QueryData(context: self.context)
    b1.category = 2
    b1.value = "JSON Derulo"
    
    let c = QueryData(context: self.context)
    c.category = 3
    c.value = "foods"
    c.relatedMetadata = "foodslists.tk - Google doc of foods people eat"
    
    do {
      try context.save()
    } catch {
      print("Error while saving items: \(error)")
    }
  }
  
  func clearData() {
    // Create the delete request for the specified entity.
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = QueryData.fetchRequest()
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    
    do {
      try self.context.execute(deleteRequest)
    } catch let error as NSError {
      print(error)
    }
  }
}
