//
//  ContentView.swift
//  Laser-laseran
//
//  Created by Muhammad Abdul Ghani on 25/05/23.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable{
    typealias UIViewType = <#type#>
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        <#code#>
    }
    
    
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
