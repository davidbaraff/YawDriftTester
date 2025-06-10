//
//  ContentView.swift
//  YawDriftTester
//
//  Created by David Baraff on 6/9/25.
//

import SwiftUI

fileprivate func p(_ pt: CGPoint, _ proxy: GeometryProxy) -> CGPoint {
    CGPoint(x: pt.x * proxy.size.width,
            y: pt.y * proxy.size.height)
}

struct ContentView: View {
    let sessionMC = SessionMC.shared
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                CameraView()
                    .contentShape(Rectangle())
                
                Path { path in
                    path.move(to: p(.init(0.5, 0), proxy))
                    path.addLine(to: p(.init(0.5, 1), proxy))
                }.stroke(Color.green, lineWidth: 2)
            }
            
            VStack {
                HStack {
                    Spacer().frame(width: 100)
                    Text(String(format: "%d:%.2d:%.2d", sessionMC.runningTime/3600,
                                sessionMC.runningTime % 3600 / 60,
                                sessionMC.runningTime % 60))
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                        .monospacedDigit()
                        .padding(10)
                        .background(Color(white: 0.2, opacity: 0.5))
                        .cornerRadius(10)

                    Spacer()
                    Text("Next change: \(sessionMC.nextChangeSeconds)")
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                        .monospacedDigit()
                        .padding(10)
                        .background(Color(white: 0.2, opacity: 0.5))
                        .cornerRadius(10)

                    Spacer().frame(width: 100)
                }.padding()
                Spacer()
                Text(String(format: "%.1f°", sessionMC.currentYaw.asDegrees))
                    .foregroundColor(.white)
                    .font(.system(size: 60))
                    .bold().monospaced()
                Spacer()
            }
            .padding()
        }
    }
}

/*
 #Preview {
 ContentView()
 }
 */
