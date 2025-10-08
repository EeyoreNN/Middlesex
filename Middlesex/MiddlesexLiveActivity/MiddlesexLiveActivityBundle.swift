//
//  MiddlesexLiveActivityBundle.swift
//  MiddlesexLiveActivity
//
//  Created by Nick Noon on 10/6/25.
//

import WidgetKit
import SwiftUI

@main
struct MiddlesexLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MiddlesexLiveActivity()
        MiddlesexLiveActivityControl()
        MiddlesexLiveActivityLiveActivity()
        if #available(iOS 16.2, *) {
            MiddlesexSportsLiveActivity()
        }
    }
}
