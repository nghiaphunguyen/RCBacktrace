//
//  StackFrame.swift
//  RCBacktrace
//
//  Created by roy.cao on 2019/8/27.
//  Copyright © 2019 roy. All rights reserved.
//

import Foundation

struct StackSymbol: CustomStringConvertible {
    public let symbol: String
    public let file: String
    public let address: UInt
    public let demangledSymbol: String
    public let image: String
    public let offset: UInt
    public let index: Int

    private init(
        symbol: String,
        file: String,
        address: UInt,
        demangledSymbol: String,
        image: String,
        offset: UInt,
        index: Int
    ) {
        self.symbol = symbol
        self.file = file
        self.address = address
        self.demangledSymbol = demangledSymbol
        self.image = image
        self.offset = offset
        self.index = index
    }

    init(address: UInt, index: Int) {
        var info = dl_info()
        dladdr(UnsafeRawPointer(bitPattern: address), &info)

        let symbol = info.symbol
        self.init(
            symbol: symbol,
            file: info.dli_fname.flatMap { String(cString: $0) } ?? "",
            address: address,
            demangledSymbol: stdlib_demangleName(symbol),
            image: info.imageName,
            offset: info.offset(with: address),
            index: index
        )
    }

    var description: String {
        image.utf8CString.withUnsafeBufferPointer { (imageBuffer: UnsafeBufferPointer<CChar>) -> String in
#if arch(x86_64) || arch(arm64)
            return String(
                format: "%-4ld%-35s 0x%016llx %@ + %ld",
                index,
                UInt(bitPattern: imageBuffer.baseAddress),
                address,
                demangledSymbol,
                offset
            )
#else
            return String(
                format: "%-4d%-35s 0x%08lx %@ + %d",
                index,
                UInt(bitPattern: imageBuffer.baseAddress),
                address,
                demangledSymbol,
                offset
            )
#endif
        }
    }
}

extension dl_info {
    /// returns: the "image" (shared object pathname) for the instruction
    fileprivate var imageName: String {
        if let dliFileName = dli_fname, let fname = String(validatingUTF8: dliFileName),
           let _ = fname.range(of: "/", options: .backwards, range: nil, locale: nil) {
            return (fname as NSString).lastPathComponent
        }
        else {
            return "???"
        }
    }

    /// returns: the symbol nearest the address
    fileprivate var symbol: String {
        if let dliSourceName = dli_sname, let sname = String(validatingUTF8: dliSourceName) {
            return sname
        }
        else if let dliFileName = dli_fname, let _ = String(validatingUTF8: dliFileName) {
            return imageName
        }
        else if let dliSourceAddress = dli_saddr {
            return String(format: "0x%1x", UInt(bitPattern: dliSourceAddress))
        }
        else {
            return "???"
        }
    }

    /// returns: the address' offset relative to the nearest symbol
    fileprivate func offset(with address: UInt) -> UInt {
        if let dliSourceName = dli_sname, let _ = String(validatingUTF8: dliSourceName),
           let dliSourceAddress = dli_saddr {
            return address.safeSub(UInt(bitPattern: dliSourceAddress))
        }
        else if let dliFileName = dli_fname, let _ = String(validatingUTF8: dliFileName),
                let dliFileBase = dli_fbase {
            return address.safeSub(UInt(bitPattern: dliFileBase))
        }
        else if let dliSourceAddrss = dli_saddr {
            return address.safeSub(UInt(bitPattern: dliSourceAddrss))
        } else {
            return 0
        }
    }
}

extension UInt {
    fileprivate func safeSub(_ b: UInt) -> UInt {
        self >= b ? self - b : 0
    }
}
