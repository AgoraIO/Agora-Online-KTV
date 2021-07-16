//
//  MusicListDialog.swift
//  LiveKtv
//
//  Created by XC on 2021/6/15.
//

import Core
import Foundation
import UIKit

protocol OrderMusicDelegate: AnyObject {
    func isOrdered(music: LocalMusic) -> Bool
    func order(music: LocalMusic)
    func isPlaying(music: LiveKtvMusic) -> Bool
}

private class OrderMusicCell: UITableViewCell {
    weak var delegate: OrderMusicDelegate!
    var music: LocalMusic! {
        didSet {
            nameView.text = music.name
            orderButton.isEnabled = !delegate.isOrdered(music: music)
            orderButton.backgroundColor = orderButton.isEnabled ? UIColor(hex: Colors.Blue) : UIColor(hex: Colors.Blue).withAlphaComponent(0.3)
        }
    }

    private var coverView: UIImageView = {
        let view = RoundImageView()
        view.radius = 8
        view.image = UIImage(named: "bg", in: Utils.bundle, with: nil)
        return view
    }()

    private var nameView: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Text)
        view.font = UIFont.systemFont(ofSize: 12)
        return view
    }()

    private var orderButton: RoundButton = {
        let view = RoundButton()
        view.backgroundColor = UIColor(hex: Colors.Blue)
        view.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        view.setTitle("点歌", for: .normal)
        view.setTitle("已点", for: .disabled)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        // selectedBackgroundView = UIView()
        contentView.isUserInteractionEnabled = true
        addSubview(coverView)
        addSubview(nameView)
        addSubview(orderButton)

        coverView.width(constant: 52)
            .height(constant: 52)
            .marginTop(anchor: topAnchor, constant: 8)
            .marginLeading(anchor: leadingAnchor, constant: 15)
            .marginBottom(anchor: bottomAnchor, constant: 8)
            .active()
        nameView.marginLeading(anchor: coverView.trailingAnchor, constant: 8)
            .centerY(anchor: coverView.centerYAnchor)
            .active()
        orderButton.marginTrailing(anchor: trailingAnchor, constant: 15)
            .centerY(anchor: coverView.centerYAnchor)
            .width(constant: 60)
            .height(constant: 32)
            .active()

        orderButton.addTarget(self, action: #selector(orderMusic), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func orderMusic() {
        delegate.order(music: music)
    }
}

private class LocalMusicList: UITableView, UITableViewDataSource, OrderMusicDelegate {
    weak var roomDelegate: RoomController?

    var data: [LocalMusic] = []

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        register(OrderMusicCell.self, forCellReuseIdentifier: NSStringFromClass(OrderMusicCell.self))
        scrollsToTop = false
        dataSource = self
        allowsSelection = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        separatorStyle = .none
        backgroundColor = .clear
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: OrderMusicCell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(OrderMusicCell.self), for: indexPath) as! OrderMusicCell
        cell.delegate = self
        cell.music = data[indexPath.row]
        return cell
    }

    func isOrdered(music: LocalMusic) -> Bool {
        return roomDelegate?.viewModel.musicList.contains { liveMusic in
            liveMusic.musicId == music.id && liveMusic.userId == roomDelegate?.viewModel.member.userId
        } ?? false
    }

    func order(music: LocalMusic) {
        roomDelegate?.viewModel.order(music: music) { [weak self] waiting in
            if let self = self {
                self.roomDelegate?.show(processing: waiting)
            }
        } onSuccess: { [weak self] in
            if let self = self {
                self.reloadData()
            }
        } onError: { [weak self] message in
            if let self = self {
                self.roomDelegate?.show(message: message, type: .error)
            }
        }
    }

    func isPlaying(music _: LiveKtvMusic) -> Bool {
        false
    }
}

private class LiveMusicCell: UITableViewCell {
    weak var delegate: OrderMusicDelegate!
    var music: LiveKtvMusic! {
        didSet {
            nameView.text = music.name
            let isPlaying = delegate.isPlaying(music: music)
            indexView.isHidden = isPlaying
            icon.isHidden = !isPlaying
            statusView.isHidden = !isPlaying
        }
    }

    var index: Int = 0 {
        didSet {
            indexView.text = String(index + 1)
        }
    }

    private var indexView: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Gray)
        view.font = UIFont.systemFont(ofSize: 18)
        return view
    }()

    private var icon: UIImageView = {
        let view = UIImageView()
        view.width(constant: 12)
            .height(constant: 13)
            .active()
        view.image = UIImage(named: "iconPlaying", in: Utils.bundle, with: nil)
        return view
    }()

    private var coverView: UIImageView = {
        let view = RoundImageView()
        view.radius = 8
        view.image = UIImage(named: "bg", in: Utils.bundle, with: nil)
        return view
    }()

    private var nameView: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Text)
        view.font = UIFont.systemFont(ofSize: 12)
        return view
    }()

    private var statusView: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Text).withAlphaComponent(0.6)
        view.font = UIFont.systemFont(ofSize: 12)
        view.text = "正在演唱"
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectedBackgroundView = UIView()

        addSubview(indexView)
        addSubview(icon)
        addSubview(coverView)
        addSubview(nameView)
        addSubview(statusView)

        indexView.centerX(anchor: leadingAnchor, constant: 19)
            .centerY(anchor: centerYAnchor)
            .active()
        icon.centerX(anchor: leadingAnchor, constant: 19)
            .centerY(anchor: centerYAnchor)
            .active()
        coverView.width(constant: 52)
            .height(constant: 52)
            .marginTop(anchor: topAnchor, constant: 8)
            .marginLeading(anchor: leadingAnchor, constant: 38)
            .marginBottom(anchor: bottomAnchor, constant: 8)
            .active()
        nameView.marginLeading(anchor: coverView.trailingAnchor, constant: 8)
            .centerY(anchor: coverView.centerYAnchor)
            .active()
        statusView.marginTrailing(anchor: trailingAnchor, constant: 15)
            .centerY(anchor: coverView.centerYAnchor)
            .active()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class LiveMusicList: UITableView, UITableViewDataSource, OrderMusicDelegate {
    weak var roomDelegate: RoomController?

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        register(LiveMusicCell.self, forCellReuseIdentifier: NSStringFromClass(LiveMusicCell.self))
        scrollsToTop = false
        dataSource = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        separatorStyle = .none
        backgroundColor = .clear
        return roomDelegate?.viewModel.musicList.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LiveMusicCell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(LiveMusicCell.self), for: indexPath) as! LiveMusicCell
        cell.delegate = self
        cell.music = roomDelegate!.viewModel.musicList[indexPath.row]
        cell.index = indexPath.row
        return cell
    }

    func isOrdered(music _: LocalMusic) -> Bool {
        return false
    }

    func order(music _: LocalMusic) {}

    func isPlaying(music: LiveKtvMusic) -> Bool {
        return roomDelegate?.viewModel.playingMusic?.id == music.id
    }
}

private protocol SearchViewDelegate: AnyObject {
    func onSearch(text: String)
}

private class SearchView: UIView, UITextFieldDelegate {
    weak var delegate: SearchViewDelegate?

    private var icon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "iconSearch", in: Utils.bundle, with: nil)
        return view
    }()

    private var editor: UITextField = {
        let view = UITextField()
        view.borderStyle = .none
        view.attributedPlaceholder = NSAttributedString(string: "搜索歌曲", attributes: [NSAttributedString.Key.foregroundColor: UIColor(hex: "#7e7e7e")])
        view.font = UIFont.systemFont(ofSize: 14)
        view.textColor = UIColor(hex: "#ccffffff")
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .search
        return view
    }()

    var text: String {
        return editor.text ?? ""
    }

    init() {
        super.init(frame: .zero)
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#bd000000")
        view.rounded(radius: 16)
        addSubview(view)
        view.height(constant: 32)
            .marginLeading(anchor: leadingAnchor)
            .marginTrailing(anchor: trailingAnchor)
            .centerY(anchor: centerYAnchor)
            .active()
        view.addSubview(icon)
        icon.width(constant: 16)
            .height(constant: 16)
            .marginLeading(anchor: view.leadingAnchor, constant: 12)
            .centerY(anchor: view.centerYAnchor)
            .active()
        view.addSubview(editor)
        editor.marginLeading(anchor: icon.trailingAnchor, constant: 6)
            .marginTrailing(anchor: view.trailingAnchor, constant: 12)
            .marginTop(anchor: view.topAnchor, constant: 5)
            .marginBottom(anchor: view.bottomAnchor, constant: 5)
            .active()
        editor.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func endEditing(_ force: Bool) -> Bool {
        return editor.endEditing(force)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            _ = editor.endEditing(true)
            delegate?.onSearch(text: text)
            return true
        } else {
            return false
        }
    }
}

private protocol HeaderViewDelegate: AnyObject {
    func onSelect(index: Int)
}

private class HeaderView: UIView {
    weak var delegate: HeaderViewDelegate?

    var count: Int = 0 {
        didSet {
            lable2.text = String(count)
        }
    }

    var index: Int = 0 {
        didSet {
            if index == 0 {
                lable0.titleLabel?.textColor = UIColor(hex: Colors.DialogTitle)
                lable1.textColor = UIColor(hex: Colors.Gray)
                lable2.textColor = UIColor(hex: Colors.Gray)
                view0.isHidden = false
                view1.isHidden = true
            } else {
                lable0.titleLabel?.textColor = UIColor(hex: Colors.Gray)
                lable1.textColor = UIColor(hex: Colors.DialogTitle)
                lable2.textColor = UIColor(hex: Colors.DialogTitle)
                view0.isHidden = true
                view1.isHidden = false
            }
        }
    }

    private var lable0: UIButton = {
        let view = UIButton()
        view.titleLabel?.textColor = UIColor(hex: Colors.DialogTitle)
        view.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        view.setTitle("点歌", for: .normal)
        return view
    }()

    private var view0: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: Colors.Blue)
        view.height(constant: 3)
            .width(constant: 54)
            .active()
        return view
    }()

    private var lable1: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.DialogTitle)
        view.font = UIFont.systemFont(ofSize: 14)
        view.text = "已点"
        return view
    }()

    private var view1: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: Colors.Blue)
        view.height(constant: 3)
            .width(constant: 54)
            .active()
        return view
    }()

    private var lable2: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Gray)
        view.font = UIFont.systemFont(ofSize: 12)
        view.text = "0"
        return view
    }()

    init() {
        super.init(frame: .zero)
        addSubview(lable0)
        addSubview(view0)
        view0.marginLeading(anchor: leadingAnchor, constant: 0)
            .marginBottom(anchor: bottomAnchor, constant: 0)
            .active()
        lable0.height(constant: 48)
            .centerX(anchor: view0.centerXAnchor)
            .centerY(anchor: centerYAnchor)
            .active()

        addSubview(view1)
        let view = UIView()
        view.addSubview(lable1)
        view.addSubview(lable2)
        lable1.marginLeading(anchor: view.leadingAnchor)
            .marginTop(anchor: view.topAnchor)
            .marginBottom(anchor: view.bottomAnchor)
            .active()
        lable2.marginLeading(anchor: lable1.trailingAnchor, constant: 3)
            .marginTop(anchor: view.topAnchor, constant: 15)
            .marginTrailing(anchor: view.trailingAnchor)
            .active()
        addSubview(view)

        view1.marginLeading(anchor: view0.trailingAnchor, constant: 60)
            .marginTrailing(anchor: trailingAnchor)
            .marginBottom(anchor: bottomAnchor, constant: 0)
            .active()
        view.height(constant: 48)
            .centerX(anchor: view1.centerXAnchor)
            .centerY(anchor: centerYAnchor)
            .active()

        lable0.addTarget(self, action: #selector(onSelect(sender:)), for: .touchUpInside)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSelect(sender:))))
    }

    @objc func onSelect(sender: Any) {
        index = sender as! NSObject == lable0 ? 0 : 1
        delegate?.onSelect(index: index)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MusicListDialog: Dialog, UIScrollViewDelegate, HeaderViewDelegate, SearchViewDelegate {
    weak var delegate: RoomController! {
        didSet {
            scrollView.contentSize.width = delegate.view.bounds.width * 2
            // localMusicList.bounds = CGRect(x: 0, y: 0, width: delegate.view.bounds.width, height: 300)
            localMusicList.roomDelegate = delegate
            localMusicList.reloadData()
            liveMusicList.roomDelegate = delegate
            liveMusicList.reloadData()
        }
    }

    private var header: HeaderView = {
        let view = HeaderView()
        view.count = 0
        view.index = 0
        return view
    }()

    private var searchView = SearchView()

    private var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.bounces = false
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = true
        return view
    }()

    private var localMusicList: LocalMusicList = {
        let view = LocalMusicList()
        return view
    }()

    private var emptyView: UILabel = {
        let view = UILabel()
        view.text = "未找到相关搜索结果"
        view.textAlignment = .center
        view.textColor = UIColor(hex: "#7e7e7e")
        view.font = UIFont.systemFont(ofSize: 14)
        return view
    }()

    private var liveMusicList: LiveMusicList = {
        let view = LiveMusicList()
        return view
    }()

    private var tipsView: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: Colors.Text).withAlphaComponent(0.59)
        view.font = UIFont.systemFont(ofSize: 12)
        view.text = "歌曲来自咪咕音乐"
        return view
    }()

    override func setup() {
        backgroundColor = UIColor(hex: Colors.Primary)
        addSubview(tipsView)
        addSubview(scrollView)

        tipsView.marginBottom(anchor: safeAreaLayoutGuide.bottomAnchor, constant: 11)
            .centerX(anchor: centerXAnchor)
            .marginLeading(anchor: leadingAnchor, constant: 15, relation: .greaterOrEqual)
            .active()
        let view = UIView()
        view.backgroundColor = UIColor(hex: Colors.Dark)
        addSubview(view)
        view.height(constant: 48)
            .marginTop(anchor: topAnchor)
            .marginLeading(anchor: leadingAnchor)
            .marginTrailing(anchor: trailingAnchor)
            .active()
        view.addSubview(header)
        header.marginTop(anchor: view.topAnchor)
            .marginBottom(anchor: view.bottomAnchor)
            .marginLeading(anchor: view.leadingAnchor, constant: 0, relation: .greaterOrEqual)
            .centerX(anchor: view.centerXAnchor)
            .active()
        scrollView.height(constant: 450, relation: .greaterOrEqual)
            .marginTop(anchor: view.bottomAnchor, constant: 0)
            .marginLeading(anchor: leadingAnchor, constant: 0)
            .marginTrailing(anchor: trailingAnchor, constant: 0)
            .marginBottom(anchor: tipsView.topAnchor, constant: 11)
            .active()

        scrollView.addSubview(searchView)
        searchView.marginLeading(anchor: scrollView.leadingAnchor, constant: 15)
            .width(equalTo: scrollView.widthAnchor, constant: -15 * 2)
            .height(constant: 32)
            .marginTop(anchor: scrollView.topAnchor, constant: 16)
            .active()

        scrollView.addSubview(localMusicList)
        localMusicList.marginLeading(anchor: scrollView.leadingAnchor)
            .width(equalTo: scrollView.widthAnchor)
            .marginTop(anchor: searchView.bottomAnchor, constant: 16)
            .height(equalTo: scrollView.heightAnchor, constant: -16 * 2 - 32)
            .active()

        scrollView.addSubview(liveMusicList)
        liveMusicList.marginLeading(anchor: localMusicList.trailingAnchor)
            .width(equalTo: scrollView.widthAnchor)
            .height(equalTo: scrollView.heightAnchor)
            .active()

        scrollView.delegate = self
        header.delegate = self
        searchView.delegate = self
    }

    override func touchesBegan(_: Set<UITouch>, with _: UIEvent?) {
        UIApplication
            .shared
            .sendAction(#selector(UIApplication.resignFirstResponder),
                        to: nil, from: nil, for: nil)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        header.index = Int(scrollView.contentOffset.x / scrollView.bounds.width)
    }

    func onSelect(index: Int) {
        if index == 0 {
            header.index = 0
            scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        } else {
            header.index = 1
            scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width, y: 0), animated: true)
        }
    }

    func onSearch(text: String) {
        Logger.log(self, message: "onSearch \(text)", level: .info)
        delegate.viewModel.search(music: text) { [unowned self] waiting in
            self.show(processing: waiting, message: "歌曲搜索中")
        } onSuccess: { [unowned self] list in
            localMusicList.data = list
            localMusicList.reloadData()
            if list.count == 0 {
                if emptyView.superview == nil {
                    scrollView.addSubview(emptyView)
                    emptyView.fill(view: localMusicList)
                        .active()
                }
            } else {
                if emptyView.superview != nil {
                    emptyView.removeFromSuperview()
                }
            }
        } onError: { [unowned self] message in
            self.delegate.show(message: message, type: .error)
        }
    }

    func show(delegate: RoomController) {
        self.delegate = delegate
        onSelect(index: 0)
        reload()
        show(controller: delegate)
        onSearch(text: searchView.text)
    }

    func reload() {
        localMusicList.reloadData()
        liveMusicList.reloadData()
        header.count = delegate.viewModel.musicList.count
    }
}
