//
//  ChatApi.swift
//  LoveMinus
//
//  Created by kohei saito on 2019/12/11.
//  Copyright © 2019 kohei saito. All rights reserved.
//

import Foundation

class ChatApi {
    static func getMessage(message: String, completion: @escaping (ChatStruct) -> Swift.Void) {

        let url =  "your api url"

        let task = URLSession.shared.dataTask(with: url!) { data, response, error in

            guard let jsonData = data else {
                return
            }

            do {
                let chat = try JSONDecoder().decode(ChatStruct.self, from: jsonData)
                completion(chat)
            } catch {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
}
