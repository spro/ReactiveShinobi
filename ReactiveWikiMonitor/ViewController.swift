//
//  ViewController.swift
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 26/06/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

import UIKit


class ViewController: UIViewController {
  
  // Public properties (for IB)
  @IBOutlet var chart: ShinobiChart
  @IBOutlet var tickerLabel: UILabel
  
  // Private properties
  var datasource: LiveDataSource?
  var wsConnector: WebSocketConnector

  // Initialisation
  init(coder aDecoder: NSCoder!) {
    wsConnector = WebSocketConnector(url: NSURL(string: "ws://wiki-update-sockets.herokuapp.com/"))
    super.init(coder: aDecoder)
  }
  
  
  // Lifecycle
  override func viewDidLoad() {
    // Prepare the chart
    chart.title = "Wikipedia Live Updates"
    let xAxis = SChartDateTimeAxis()
    let yAxis = SChartNumberAxis(range: SChartNumberRange(minimum: 0, andMaximum: 5))
    yAxis.title = "Edit Rate (edits/second)"
    chart.xAxis = xAxis
    chart.yAxis = yAxis
    
    chart.licenseKey = ""
    
    // Create the data source
    datasource = LiveDataSource(chart: chart)
    
    // Start listening to the websocket
    wsConnector.start()
    
    // Create the streams
    createPipelines()
  }
  
  // Utility methods
  func createPipelines() {
    // Create a scheduler
    let scheduler = RACScheduler(priority: RACSchedulerPriorityDefault, name: "com.shinobicontrols.ReactiveWikiMonitor.bufferScheduler")
    
    // Calculate the rate
    wsConnector.messages
      .bufferWithTime(5, onScheduler: scheduler)
      .mapAs({ (value: RACTuple) -> NSNumber in
        return NSNumber(double: Double(value.count) / 5.0)
        })
      .deliverOn(RACScheduler.mainThreadScheduler())
      .logNext()
      .subscribeNext({(x: AnyObject!) in self.datasource!.appendValue(x as NSNumber)})
    
    // Extract the edited content
    wsConnector.messages
      .filterAs({ (dict: NSDictionary) in
          return (dict["type"] as NSString).isEqualToString("unspecified")
        })
      .mapAs({ (dict: NSDictionary) -> NSString in
        return dict["content"] as NSString
        })
      .deliverOn(RACScheduler.mainThreadScheduler())
      .subscribeNextAs({(value: NSString) in
        self.tickerLabel.text = value
        })
    
    // Find the new user events
    wsConnector.messages
      .filterAs({ (value: NSDictionary) -> Bool in
          return (value["type"] as NSString).isEqualToString("newuser")
        })
      .mapAs({ (value: NSDictionary) -> SChartAnnotation in
        return self.createNewUserAnnotation(value["time"])
        })
      .deliverOn(RACScheduler.mainThreadScheduler())
      .subscribeNextAs({ (value: SChartAnnotation) in
        self.chart.addAnnotation(value)
        self.chart.redrawChart()
        })
  }
  
  // Utility function
  func createNewUserAnnotation(time: AnyObject!) -> SChartAnnotation {
    return SChartAnnotation.verticalLineAtPosition(time, withXAxis: self.chart.xAxis, andYAxis: self.chart.yAxis, withWidth: 2.0, withColor: UIColor.redColor().colorWithAlphaComponent(0.5))
  }
  
  
  // Appearance
  override func supportedInterfaceOrientations() -> Int {
    return Int(UIInterfaceOrientationMask.Landscape.toRaw())
  }
  
  
}