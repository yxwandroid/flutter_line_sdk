import Flutter
import UIKit

import LineSDK

public class SwiftFlutterLineSdkPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.wilson.mtech/channel";
  private var myChannel: FlutterMethodChannel?
    
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.linecorp/flutter_line_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLineSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    
     let lineChannel = FlutterMethodChannel(name: channelName,
                                            binaryMessenger: registrar.messenger())
      lineChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        // Note: this method is invoked on the UI thread.
        if call.method == "toLinePay" {
            instance.receiveNativeData(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
      instance.myChannel = lineChannel

  }
  private  func receiveNativeData(result: FlutterResult) {
       // Perform native operations to get data
       let data = "This is data from iOS"
       result(data)
 }
    

  func parseCustomURLScheme(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host,
              let queryItems = components.queryItems else {
            return
        }
        
        // host可能包含端口信息，这里我们不需要端口信息
        let path = host + (components.path.isEmpty ? "" : components.path) // "pay/LinePayPage"
        
        // 提取查询参数
        let transactionId = queryItems.first(where: { $0.name == "transactionId" })?.value
        let orderId = queryItems.first(where: { $0.name == "orderId" })?.value
        
        // 根据path和查询参数执行相应的逻辑
        // 例如，跳转到支付页面
        if path == "pay/LinePayPage", let transactionId = transactionId, let orderId = orderId {
            // 执行支付流程
            handlePayment(transactionId: transactionId, orderId: orderId)
        }
    }
    
     func handlePayment(transactionId: String, orderId: String) {
        // 处理支付逻辑
        print("处理支付，交易ID: \(transactionId), 订单ID: \(orderId)")
        // 创建一个字典，与 Kotlin 中使用 mapOf 类似
        let map: [String: String] = [
            "transactionId": transactionId,
            "orderId": orderId
        ]

        // 调用 Flutter 端的 'getPayMessage' 方法
        myChannel?.invokeMethod("getPayMessage", arguments: map) { (result: Any?) in
            // 这里处理回调结果
            if let error = result as? FlutterError {
                print("Flutter error: \(error.message ?? "")")
            } else if FlutterMethodNotImplemented.isEqual(result) {
                print("Flutter method not implemented.")
            } else {
                // 成功获取到结果
                print("Received result: \(String(describing: result))")
            }
        }

    }
    
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    guard let method = LineChannelMethod(rawValue: call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }

    let arguments = call.arguments as? [String: Any]
    method.call(arguments: arguments, result: result)
  }

  public  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
  {
      
              print("wilson--------2")
              print(url.scheme)
              print("wilson--------")
      if(url.scheme == "mtech"){
          parseCustomURLScheme(url: url)

      }
      return LoginManager.shared.application(application, open: url, options: options)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void) -> Bool
  {
    return LoginManager.shared.application(application, open: userActivity.webpageURL)
  }
}

extension LineSDKError {
  var flutterError: FlutterError {
    return FlutterError(code: String(errorCode), message: errorDescription, details: errorUserInfo.description)
  }
}

extension FlutterError {
  static let nilArgument = FlutterError(
    code: "argument.nil",
    message: "Expect an argument when invoking channel method, but it is nil.", details: nil
  )

  static func failedArgumentField<T>(_ fieldName: String, type: T.Type) -> FlutterError {
    return .init(
      code: "argument.failedField",
      message: "Expect a `\(fieldName)` field with type <\(type)> in the argument, " +
               "but it is missing or type not matched.",
      details: fieldName)
  }
}

enum LineChannelMethod: String {
  case setup
  case login
  case logout
  case getProfile
  case refreshToken
  case verifyAccessToken
  case getBotFriendshipStatus
  case currentAccessToken

  #if LINE_FLUTTER_BETA_ENV_COMPATIBLE
  case toBeta
  #endif

  func call(arguments: [String: Any]?, result: @escaping FlutterResult) {

    let runner: (_ arguments: [String: Any]?, _ result: @escaping FlutterResult) -> Void

    switch self {
    case .setup:                  runner = setup
    case .login:                  runner = login
    case .logout:                 runner = logout
    case .getProfile:             runner = getProfile
    case .refreshToken:           runner = refreshToken
    case .verifyAccessToken:      runner = verifyAccessToken
    case .getBotFriendshipStatus: runner = getBotFriendshipStatus
    case .currentAccessToken:     runner = currentAccessToken

    #if LINE_FLUTTER_BETA_ENV_COMPATIBLE
    case .toBeta:                 runner = toBeta
    #endif
    }

    runner(arguments, result)
  }
}

extension LineChannelMethod {

  func setup(arguments: [String: Any]?, result: @escaping FlutterResult) {
    
    guard !LoginManager.shared.isSetupFinished else {
        result(nil)
        return
    }

    guard let args = arguments else {
      result(FlutterError.nilArgument)
      return
    }

    guard let channelId = args["channelId"] as? String else {
      result(FlutterError.failedArgumentField("channelId", type: String.self))
      return
    }

    let universalLinkURL = (args["universalLink"] as? String)
      .map { URL(string: $0) } ?? nil
    LoginManager.shared.setup(channelID: channelId, universalLinkURL: universalLinkURL)
    result(nil)
  }

  func login(arguments: [String: Any]?, result: @escaping FlutterResult) {

    guard let args = arguments else {
      result(FlutterError.nilArgument)
      return
    }

    let scopes = (args["scopes"] as? [String])?.map { LoginPermission(rawValue: $0) } ?? [.profile]
    
    var parameters = LoginManager.Parameters()
    parameters.onlyWebLogin = (args["onlyWebLogin"] as? Bool) ?? false
    parameters.IDTokenNonce = args["idTokenNonce"] as? String
      
    if let botPrompt = args["botPrompt"] as? String {
      switch botPrompt {
      case "aggressive": parameters.botPromptStyle = .aggressive
      case "normal": parameters.botPromptStyle = .normal
      default: break
      }
    }

    LoginManager.shared.login(
      permissions: Set(scopes),
      in: nil,
      parameters: parameters) { r in
        switch r {
        case .success(let value): result(value.json)
        case .failure(let error): result(error.flutterError)
        }
    }
  }

  func logout(arguments: [String: Any]?, result: @escaping FlutterResult) {
    LoginManager.shared.logout { r in
      switch r {
      case .success: result(nil)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func getProfile(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.getProfile { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func refreshToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.Auth.refreshAccessToken { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func verifyAccessToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.Auth.verifyAccessToken { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func getBotFriendshipStatus(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.getBotFriendshipStatus { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func currentAccessToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    result(AccessTokenStore.shared.current?.json)
  }

  #if LINE_FLUTTER_BETA_ENV_COMPATIBLE
  func toBeta(arguments: [String: Any]?, result: @escaping FlutterResult) {
    LineSDK.Constant.toBeta()
    result(nil)
  }
  #endif
}

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
}()

extension Encodable {
  var json: String {
    let data = try! encoder.encode(self)
    return String(data: data, encoding: .utf8)!
  }
}
