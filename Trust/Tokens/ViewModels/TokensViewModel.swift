// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import RealmSwift
import TrustKeystore

enum TokenItem {
    case token(TokenObject)
}

struct TokensViewModel {
    let config: Config

    let store: TokensDataStore
    var tokensNetwork: TokensNetworkProtocol
    let tokens: Results<TokenObject>
    var tokensObserver: NotificationToken?
    let address: Address

    var headerBalance: String? {
        return amount
    }

    var headerBalanceTextColor: UIColor {
        return Colors.black
    }

    var headerBackgroundColor: UIColor {
        return .white
    }

    var headerBalanceFont: UIFont {
        return UIFont.systemFont(ofSize: 26, weight: .medium)
    }

    var title: String {
        return NSLocalizedString("tokens.navigation.title", value: "Tokens", comment: "")
    }

    var backgroundColor: UIColor {
        return .white
    }

    var hasContent: Bool {
        return !tokens.isEmpty
    }

    var footerTitle: String {
        return NSLocalizedString("tokens.footer.label.title", value: "Tokens will appear automagically. Tap + to add manually.", comment: "")
    }

    var footerTextColor: UIColor {
        return Colors.black
    }

    var footerTextFont: UIFont {
        return UIFont.systemFont(ofSize: 13, weight: .light)
    }

    init(
        config: Config = Config(),
        address: Address,
        store: TokensDataStore,
        tokensNetwork: TokensNetworkProtocol
    ) {
        self.config = config
        self.address = address
        self.store = store
        self.tokensNetwork = tokensNetwork
        self.tokens = store.tokens
        updateEthBalance()
        updateTokensBalances()
        updateTickers()
    }

    mutating func setTokenObservation(with block: @escaping (RealmCollectionChange<Results<TokenObject>>) -> Void) {
        tokensObserver = tokens.observe(block)
    }

    private var amount: String? {
        var totalAmount: Double = 0
        tokens.forEach { token in
            totalAmount += amount(for: token)
        }
        guard totalAmount != 0 else { return "--" }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }

    private func amount(for token: TokenObject) -> Double {
        guard let tickersSymbol = store.tickers.first(where: { $0.contract == token.contract }) else { return 0 }
        let tokenValue = CurrencyFormatter.plainFormatter.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        let price = Double(tickersSymbol.price) ?? 0
        return tokenValue * price
    }

    func numberOfItems(for section: Int) -> Int {
        return tokens.count
    }

    func item(for path: IndexPath) -> TokenItem {
        return .token(tokens[path.row])
    }

    func canEdit(for path: IndexPath) -> Bool {
        let token = item(for: path)
        switch token {
        case .token(let token):
            return token.isCustom
        }
    }

    func cellViewModel(for path: IndexPath) -> TokenViewCellViewModel {
        let token = tokens[path.row]
        return TokenViewCellViewModel(token: token, ticker: store.coinTicker(for: token))
    }

    func updateTickers() {
        tokensNetwork.tickers(for: store.enabledObject) { result in
            guard let tickers = result else { return }
            self.store.tickers = tickers
        }
    }

    func updateEthBalance() {
        tokensNetwork.ethBalance { result in
            guard let balance = result, let token = self.store.objects.first (where: { $0.name == self.config.server.name })  else { return }
            self.store.update(token: token, action: .updateValue(balance.value))
        }
    }

    func updateTokensBalances() {
        store.enabledObject.filter { $0.name != self.config.server.name }.forEach { token in
            tokensNetwork.tokenBalance(for: token) { result in
                guard let balance = result.1 else { return }
                self.store.update(token: result.0, action: TokenAction.updateValue(balance.value))
            }
        }
    }

    func fetchTokensList() {
        tokensNetwork.tokensList(for: address) { result in
            guard let tokensList = result else { return }
            let tokens: [Token] = tokensList.flatMap { .from(token: $0.contract) }
            TokensDataStore.update(in: self.store.realm, tokens: tokens)
        }
    }

    func fetch() {
        updateTickers()
        updateEthBalance()
        updateTokensBalances()
        fetchTokensList()
    }
}
