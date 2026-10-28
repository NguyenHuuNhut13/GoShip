import React, { useState } from 'react';
import {
  CreditCard, ArrowDownLeft, ArrowUpRight, Percent,
  Search, Check, X, AlertCircle, CheckCircle, Clock,
  Building, User, Hash, Filter
} from 'lucide-react';
import { TransactionItem, PayoutRequestItem } from '../types';

interface TransactionsViewProps {
  transactions: TransactionItem[];
  payoutRequests: PayoutRequestItem[];
  onApprovePayout: (payout: PayoutRequestItem) => Promise<void>;
  onRejectPayout: (payout: PayoutRequestItem, reason: string) => Promise<void>;
}

export function TransactionsView({
  transactions,
  payoutRequests,
  onApprovePayout,
  onRejectPayout,
}: TransactionsViewProps) {
  const [activeTab, setActiveTab] = useState<'ledger' | 'payouts'>('ledger');
  const [typeFilter, setTypeFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [processingId, setProcessingId] = useState<string | null>(null);

  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const pendingPayouts = payoutRequests.filter(p => p.status === 'pending');

  const filteredTransactions = transactions.filter(t => {
    const matchType = typeFilter === 'all' || t.type === typeFilter;
    const q = search.toLowerCase();
    const matchSearch =
      t.id.toLowerCase().includes(q) ||
      t.driver.toLowerCase().includes(q) ||
      t.note.toLowerCase().includes(q);
    return matchType && matchSearch;
  });

  const totalPages = Math.ceil(filteredTransactions.length / pageSize) || 1;
  const paginatedTransactions = filteredTransactions.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  );

  const totalDeposit = transactions
    .filter(t => t.type === 'deposit')
    .reduce((a, b) => a + Math.abs(b.amount), 0);
  const totalWithdraw = transactions
    .filter(t => t.type === 'withdraw')
    .reduce((a, b) => a + Math.abs(b.amount), 0);
  const totalComm = transactions
    .filter(t => t.type === 'commission')
    .reduce((a, b) => a + Math.abs(b.amount), 0);

  const fmtVND = (amt: number) => amt.toLocaleString('vi-VN') + ' đ';

  const TXN_TYPE_CONFIG: Record<string, { label: string; bg: string; text: string }> = {
    deposit: { label: 'Thu nhập / Nạp ký quỹ', bg: 'bg-emerald-50', text: 'text-emerald-700' },
    withdraw: { label: 'Rút tiền ngân hàng', bg: 'bg-orange-50', text: 'text-orange-700' },
    commission: { label: 'Khấu trừ 15% hoa hồng', bg: 'bg-blue-50', text: 'text-blue-700' },
    refund: { label: 'Hoàn tiền', bg: 'bg-purple-50', text: 'text-purple-700' },
  };

  const handleApprove = async (payout: PayoutRequestItem) => {
    if (!window.confirm(`Xác nhận ĐÃ CHUYỂN KHOẢN ${fmtVND(payout.amount)} cho tài xế ${payout.driverName}?`)) return;
    setProcessingId(payout.docId);
    try {
      await onApprovePayout(payout);
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (payout: PayoutRequestItem) => {
    const reason = window.prompt(
      `Nhập lý do từ chối lệnh rút tiền của tài xế ${payout.driverName}:`,
      'Số tài khoản hoặc tên ngân hàng không khớp'
    );
    if (!reason) return;
    setProcessingId(payout.docId);
    try {
      await onRejectPayout(payout, reason);
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <div className="space-y-5">
      {/* Top Main Tab Switcher */}
      <div className="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveTab('ledger')}
            className={`px-4 py-2.5 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'ledger'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            Sổ cái Giao dịch Toàn sàn
          </button>
          <button
            onClick={() => setActiveTab('payouts')}
            className={`px-4 py-2.5 rounded-xl text-xs font-bold transition-all relative ${
              activeTab === 'payouts'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            Duyệt Lệnh Rút tiền Tài xế
            {pendingPayouts.length > 0 && (
              <span className="ml-1.5 px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-400 text-slate-900">
                {pendingPayouts.length} CHỜ DUYỆT
              </span>
            )}
          </button>
        </div>

        <div className="text-xs text-slate-400">
          Quy tắc kế toán: Đơn COD khấu trừ 15% hoa hồng ký quỹ • Đơn Trả trước giải ngân 85% thu nhập
        </div>
      </div>

      {activeTab === 'ledger' ? (
        <>
          {/* Financial Overview KPIs */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center gap-4">
              <div className="p-3.5 rounded-xl bg-emerald-50">
                <ArrowDownLeft className="w-5 h-5 text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-slate-500 font-medium">Tổng giải ngân / Nạp ký quỹ</p>
                <p className="text-lg font-bold text-emerald-600 mt-0.5">+{fmtVND(totalDeposit)}</p>
              </div>
            </div>

            <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center gap-4">
              <div className="p-3.5 rounded-xl bg-orange-50">
                <ArrowUpRight className="w-5 h-5 text-orange-600" />
              </div>
              <div>
                <p className="text-xs text-slate-500 font-medium">Tổng rút thu nhập về Bank</p>
                <p className="text-lg font-bold text-orange-600 mt-0.5">-{fmtVND(totalWithdraw)}</p>
              </div>
            </div>

            <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center gap-4">
              <div className="p-3.5 rounded-xl bg-blue-50">
                <Percent className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-xs text-slate-500 font-medium">Hoa hồng nền tảng (15% Net)</p>
                <p className="text-lg font-bold text-blue-600 mt-0.5">{fmtVND(totalComm)}</p>
              </div>
            </div>
          </div>

          {/* Filters & Search */}
          <div className="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap gap-1.5">
              {[
                { key: 'all', label: `Tất cả (${transactions.length})` },
                { key: 'deposit', label: 'Cộng tiền / Giải ngân' },
                { key: 'withdraw', label: 'Rút tiền' },
                { key: 'commission', label: 'Hoa hồng 15%' },
              ].map(f => (
                <button
                  key={f.key}
                  onClick={() => {
                    setTypeFilter(f.key);
                    setCurrentPage(1);
                  }}
                  className={`px-3.5 py-2 rounded-xl text-xs font-semibold transition-all ${
                    typeFilter === f.key
                      ? 'bg-blue-600 text-white shadow-sm'
                      : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>

            <div className="relative flex-1 min-w-56 max-w-sm">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                type="text"
                placeholder="Tìm mã GD, tên tài xế, nội dung..."
                value={search}
                onChange={e => {
                  setSearch(e.target.value);
                  setCurrentPage(1);
                }}
                className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30"
              />
            </div>
          </div>

          {/* Ledger Table */}
          <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 bg-slate-50/70">
                    <th className="text-left px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Mã GD</th>
                    <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Đối tác Tài xế</th>
                    <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Loại giao dịch</th>
                    <th className="text-right px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Biến động</th>
                    <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Nội dung chi tiết</th>
                    <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Thời gian</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50">
                  {paginatedTransactions.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-5 py-12 text-center text-slate-400">
                        <CreditCard className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                        <p className="text-sm font-medium text-slate-600">Chưa có giao dịch ví nào phát sinh</p>
                      </td>
                    </tr>
                  ) : (
                    paginatedTransactions.map(txn => {
                      const cfg = TXN_TYPE_CONFIG[txn.type] ?? TXN_TYPE_CONFIG.deposit;
                      const isPos = txn.amount > 0;
                      return (
                        <tr key={txn.id} className="hover:bg-slate-50/60 transition-colors">
                          <td className="px-5 py-4 font-mono text-xs font-semibold text-slate-600">
                            {txn.id}
                            {txn.isCloud && (
                              <span className="ml-1.5 px-1.5 py-0.5 text-[10px] font-bold bg-blue-50 text-blue-600 rounded">
                                CLOUD
                              </span>
                            )}
                          </td>
                          <td className="px-4 py-4 font-medium text-slate-800">{txn.driver}</td>
                          <td className="px-4 py-4">
                            <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${cfg.bg} ${cfg.text}`}>
                              {cfg.label}
                            </span>
                          </td>
                          <td className={`px-4 py-4 text-right font-bold ${isPos ? 'text-emerald-600' : 'text-red-500'}`}>
                            {isPos ? '+' : ''}{fmtVND(txn.amount)}
                          </td>
                          <td className="px-4 py-4 text-xs text-slate-600 max-w-sm truncate">{txn.note}</td>
                          <td className="px-4 py-4 text-xs text-slate-400">{txn.time}</td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {filteredTransactions.length > 0 && (
              <div className="px-5 py-3.5 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3 text-xs text-slate-500">
                <div className="flex items-center gap-2">
                  <span>Hiển thị</span>
                  <select
                    value={pageSize}
                    onChange={e => {
                      setPageSize(Number(e.target.value));
                      setCurrentPage(1);
                    }}
                    className="bg-slate-50 border border-slate-200 rounded-lg px-2 py-1 text-xs focus:outline-none"
                  >
                    <option value={10}>10</option>
                    <option value={25}>25</option>
                    <option value={50}>50</option>
                  </select>
                  <span>trên tổng {filteredTransactions.length} giao dịch</span>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    disabled={currentPage <= 1}
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
                  >
                    Trước
                  </button>
                  <span className="px-3 py-1 font-semibold text-slate-800">
                    {currentPage} / {totalPages}
                  </span>
                  <button
                    disabled={currentPage >= totalPages}
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
                  >
                    Sau
                  </button>
                </div>
              </div>
            )}
          </div>
        </>
      ) : (
        /* Payout Requests Tab */
        <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
          <div className="p-5 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h3 className="font-bold text-slate-800 text-base">Danh sách Yêu cầu Rút tiền Ngân hàng</h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Kiểm tra thông tin tài khoản ngân hàng và bấm "Duyệt chi" sau khi đã chuyển khoản Internet Banking thành công
              </p>
            </div>
            <div className="text-xs font-semibold text-amber-700 bg-amber-50 px-3 py-1.5 rounded-xl border border-amber-200">
              {pendingPayouts.length} yêu cầu đang chờ xử lý
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/70">
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Mã yêu cầu</th>
                  <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Tài xế rút tiền</th>
                  <th className="text-right px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Số tiền yêu cầu</th>
                  <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Thông tin Ngân hàng thụ hưởng</th>
                  <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Thời gian</th>
                  <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Trạng thái</th>
                  <th className="text-center px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Hành động</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {payoutRequests.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                      <Clock className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                      <p className="text-sm font-medium text-slate-600">Chưa có yêu cầu rút tiền nào</p>
                      <p className="text-xs text-slate-400">Khi tài xế tạo lệnh rút tiền từ App Driver, yêu cầu sẽ hiển thị ở đây để Admin duyệt.</p>
                    </td>
                  </tr>
                ) : (
                  payoutRequests.map(payout => {
                    const isPending = payout.status === 'pending';
                    const isApproved = payout.status === 'approved';

                    return (
                      <tr key={payout.docId || payout.id} className="hover:bg-slate-50/60 transition-colors">
                        <td className="px-5 py-4 font-mono text-xs font-bold text-slate-700">{payout.id}</td>
                        <td className="px-4 py-4">
                          <div className="font-semibold text-slate-800">{payout.driverName}</div>
                          <div className="text-xs text-slate-400">{payout.driverPhone}</div>
                        </td>
                        <td className="px-4 py-4 text-right font-bold text-orange-600 text-base">
                          {fmtVND(payout.amount)}
                        </td>
                        <td className="px-4 py-4">
                          <div className="font-medium text-slate-800 flex items-center gap-1.5">
                            <Building className="w-3.5 h-3.5 text-slate-400" />
                            {payout.bankName}
                          </div>
                          <div className="text-xs font-mono font-bold text-blue-600 mt-0.5">
                            STK: {payout.accountNo}
                          </div>
                          <div className="text-xs text-slate-500 uppercase">
                            Chủ TK: {payout.holderName}
                          </div>
                        </td>
                        <td className="px-4 py-4 text-xs text-slate-400">{payout.time}</td>
                        <td className="px-4 py-4 text-center">
                          {isPending ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-50 text-amber-700">
                              <Clock className="w-3 h-3" /> Chờ duyệt
                            </span>
                          ) : isApproved ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700">
                              <CheckCircle className="w-3 h-3" /> Đã chuyển tiền
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-50 text-red-600">
                              <X className="w-3 h-3" /> Từ chối
                            </span>
                          )}
                        </td>
                        <td className="px-5 py-4 text-center">
                          {isPending ? (
                            <div className="inline-flex items-center gap-1.5">
                              <button
                                disabled={processingId === payout.docId}
                                onClick={() => handleApprove(payout)}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm transition-all"
                              >
                                <Check className="w-3.5 h-3.5" /> Duyệt chi
                              </button>
                              <button
                                disabled={processingId === payout.docId}
                                onClick={() => handleReject(payout)}
                                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-all"
                              >
                                <X className="w-3.5 h-3.5" /> Từ chối
                              </button>
                            </div>
                          ) : (
                            <span className="text-xs text-slate-400 italic">Đã hoàn tất</span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
